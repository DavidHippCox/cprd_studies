-- run ons_death_dedip.r before this
-- patient_candidates_mariadb_pipeline_v3.sql
--
-- MariaDB patient preprocessing pipeline incorporating 01_patient.sql.
-- Source date columns are native DATE columns. The patient year of birth
-- (yob) is assumed to be a four-digit integer year.
--
-- Final output retains:
--   patid, pracid, frd, crd, tod, gender, yob
-- plus linkage fields and fields derived by this pipeline.
USE gold_oxcprd_001b;

DROP VIEW IF EXISTS v_qc_patient_exclusions;

DROP VIEW IF EXISTS v_qc_patient_pipeline_counts;

DROP VIEW IF EXISTS v_candidate_first_diagnosis;

DROP VIEW IF EXISTS v_patient_earliest_4_latest_4;

DROP VIEW IF EXISTS v_patient_linked;

DROP VIEW IF EXISTS v_patient_base_eligible;

DROP TABLE IF EXISTS preproc_patient_candidates;

-- Apply patient-level eligibility from 01_patient.sql while retaining only
-- fields required downstream. accept <> 1 is preserved exactly as supplied.
CREATE VIEW v_patient_base_eligible AS
SELECT
  p.patid,
  p.pracid,
  p.frd,
  p.crd,
  p.tod,
  p.gender,
  p.yob,
  pr.lcd,
  pr.uts,
  p.deathdate AS cprd_death
FROM
  pc_patient AS p
  INNER JOIN pc_practice AS pr ON pr.pracid = p.pracid
WHERE
  p.regstat <> 99 -- 99 is code for only temporary registrations
  AND p.accept = 1 -- only "accept" patients
  AND p.gender IN (1, 2) -- only patients with gender == 1 and gender == 2
  AND p.crd IS NOT NULL
  AND DATEDIFF(LEAST(COALESCE(p.tod, pr.lcd), pr.lcd), p.crd) >= 365;

-- patients have to be registered for at least 12 months 
CREATE VIEW v_patient_linked AS
SELECT
  p.patid,
  p.pracid,
  p.frd,
  p.crd,
  p.tod,
  p.gender,
  p.yob,
  p.lcd,
  p.uts,
  le.hes_apc_e,
  le.ons_death_e,
  le.lsoa_e,
  imd.e2019_imd_10,
  imd.ni2017_imd_10,
  imd.s2020_imd_10,
  imd.w2019_imd_10,
  le.linkyear,
  od.reg_date_of_death AS ons_death,
  CASE
    WHEN CAST(pr.region AS UNSIGNED) BETWEEN 1 AND 9  THEN 'England'
    WHEN CAST(pr.region AS UNSIGNED) = 10 THEN 'Wales'
    WHEN CAST(pr.region AS UNSIGNED) = 11 THEN 'Scotland'
    WHEN CAST(pr.region AS UNSIGNED) = 12 THEN 'Northern Ireland'
    ELSE NULL
  END AS country,
  COALESCE(imd.e2019_imd_10, imd.ni2017_imd_10, imd.s2020_imd_10, imd.w2019_imd_10) AS uk_imd,
  CASE er.ethnic_6
    WHEN '1' THEN 'Asian'
    WHEN '2' THEN 'Black'
    WHEN '3' THEN 'Mixed/Multiple'
    WHEN '4' THEN 'White'
    WHEN '5' THEN 'Other'
    WHEN '6' THEN 'Unknown' -- already set to null? 
    ELSE NULL
  END AS ethnic_6_label,
  COALESCE(od.reg_date_of_death, p.cprd_death) AS merged_death
FROM
  v_patient_base_eligible AS p
  LEFT JOIN pc_practice AS pr ON pr.pracid = p.pracid
  LEFT JOIN linked_linkage_eligibility_gold AS le ON le.patid = p.patid
  LEFT JOIN linked_ethnicity_record AS er ON er.patid = p.patid
  LEFT JOIN linked_practice_imd AS imd ON imd.pracid = p.pracid
  LEFT JOIN linked_death_patient_deduplicated AS od ON od.patid = p.patid;

CREATE VIEW v_patient_earliest_4_latest_4 AS
SELECT
  p.patid,
  p.pracid,
  p.frd,
  p.crd,
  p.tod,
  p.gender,
  p.yob,
  p.hes_apc_e,
  p.ons_death_e,
  p.lsoa_e,
  p.e2019_imd_10,
  p.ni2017_imd_10,
  p.s2020_imd_10,
  p.w2019_imd_10,
  p.linkyear,
  p.ons_death,
  p.country,
  p.uk_imd,
  p.ethnic_6_label,
  p.merged_death,
  DATE '1998-01-02' AS ons_link_start,
  DATE '2024-04-03' AS ons_link_end,
  LEAST(
    COALESCE(p.lcd, DATE '9999-12-31'),
    COALESCE(p.tod, DATE '9999-12-31'),
    COALESCE(p.merged_death, DATE '9999-12-31'),
    DATE '2024-04-03' -- linkage end
  ) AS earliest_4,
  GREATEST(
    COALESCE(p.uts, DATE '1000-01-01'),
    COALESCE(p.frd, DATE '1000-01-01'),
    COALESCE(p.crd, DATE '1000-01-01'),
    DATE '1998-01-02' -- linkage start
  ) AS latest_4
FROM
  v_patient_linked AS p;

-- Find the first candidate diagnosis occurring after the estimated date of
-- birth.
CREATE VIEW v_candidate_first_diagnosis AS
SELECT
  d.patid,
  MIN(d.eventdate) AS first_diag
FROM
  candidate_patids AS d
  INNER JOIN v_patient_earliest_4_latest_4 AS p ON p.patid = d.patid
WHERE
  d.eventdate > MAKEDATE(cb.yob + 18, 1)
GROUP BY
  d.patid;

CREATE TABLE preproc_patient_candidates AS
SELECT
  p.patid,
  p.pracid,
  p.frd,
  p.crd,
  p.tod,
  p.gender,
  p.yob,
  p.hes_apc_e,
  p.ons_death_e,
  p.lsoa_e,
  p.e2019_imd_10,
  p.ni2017_imd_10,
  p.s2020_imd_10,
  p.w2019_imd_10,
  p.linkyear,
  p.ons_death,
  p.country,
  p.uk_imd,
  p.ethnic_6_label,
  p.merged_death,
  p.ons_link_start,
  p.ons_link_end,
  p.earliest_4,
  p.latest_4,
  d.first_diag,
  TIMESTAMPDIFF (YEAR, MAKEDATE(cb.yob, 1), d.first_diag) AS age_at_first_diag
FROM
  v_patient_earliest_4_latest_4 AS p
  INNER JOIN v_candidate_first_diagnosis AS d ON d.patid = p.patid
WHERE
  TIMESTAMPDIFF (YEAR, MAKEDATE(cb.yob, 1), d.first_diag) > 40
  AND (
    p.merged_death IS NULL
    OR DATEDIFF(p.merged_death, p.crd) >= 365 -- in practice for at least a 1 year (absolute value needed?)
  )
  AND (
    p.frd IS NULL
    OR p.yob IS NULL
    OR YEAR(p.frd) - p.yob <= 100 -- first reg less than 100 years old
  )
  AND (
    p.frd IS NULL
    OR p.frd >= DATE '1900-01-01'
    -- first reg before 1900-01-01 (redundant by prior step - keep for now)
  );

CREATE INDEX idx_patid ON preproc_patient_candidates (patid);

CREATE VIEW v_qc_patient_pipeline_counts AS
SELECT
  'v_patient_base_eligible' AS table_name, -- check
  COUNT(*) AS n_rows,
  COUNT(DISTINCT patid) AS n_patients
FROM
  v_patient_base_eligible
UNION ALL
SELECT
  'v_patient_linked',
  COUNT(*),
  COUNT(DISTINCT patid)
FROM
  v_patient_linked
UNION ALL
SELECT
  'v_patient_earliest_4_latest_4',
  COUNT(*),
  COUNT(DISTINCT patid)
FROM
  v_patient_earliest_4_latest_4
UNION ALL
SELECT
  'v_candidate_first_diagnosis',
  COUNT(*),
  COUNT(DISTINCT patid)
FROM
  v_candidate_first_diagnosis
UNION ALL
SELECT
  'preproc_patient_candidates',
  COUNT(*),
  COUNT(DISTINCT patid)
FROM
  preproc_patient_candidates;

CREATE VIEW v_qc_patient_exclusions AS
SELECT
  (
    SELECT
      COUNT(*)
    FROM
      pc_patient
  ) AS n_source_patients,
  (
    SELECT
      COUNT(*)
    FROM
      v_patient_base_eligible
  ) AS n_after_base_eligibility,
  (
    SELECT
      COUNT(*)
    FROM
      v_patient_earliest_4_latest_4
  ) AS n_after_linkage,
  (
    SELECT
      COUNT(*)
    FROM
      v_candidate_first_diagnosis
  ) AS n_with_candidate_diagnosis,
  (
    SELECT
      COUNT(*)
    FROM
      preproc_patient_candidates
  ) AS n_final;

ANALYZE TABLE preproc_patient_candidates;