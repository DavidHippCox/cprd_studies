-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
-- run ons_death_dedip.r before this
--
USE aurum_oxcprd_001b;

DROP TABLE IF EXISTS v_qc_patient_exclusions;

DROP TABLE IF EXISTS v_qc_patient_pipeline_counts;

DROP TABLE IF EXISTS v_candidate_first_diagnosis;

DROP TABLE IF EXISTS v_patient_earliest_4_latest_2;

DROP TABLE IF EXISTS v_patient_linked;

DROP TABLE IF EXISTS v_patient_base_eligible;

DROP TABLE IF EXISTS preproc_patient_candidates;

-- Apply patient-level eligibility from 01_patient.sql while retaining only
CREATE TABLE v_patient_base_eligible AS
SELECT
  p.patid,
  p.pracid,
  p.regstartdate,
  p.regenddate,
  p.gender,
  MAKEDATE(p.yob, 1) AS yob_date,
  pr.lcd,
  p.cprd_ddate AS cprd_death
FROM
  patient AS p
  INNER JOIN practice AS pr ON pr.pracid = p.pracid
WHERE
  p.patienttypeid = 3 -- 3 is code for only regular patients
  AND p.acceptable = 1 -- only "acceptable" patients
  AND p.gender IN (1, 2) -- only patients with gender == 1 and gender == 2
  AND p.regstartdate IS NOT NULL
  -- patients practice-time is at least 12 months (registered for at least 12 months) 
  AND DATE_ADD(p.regstartdate, INTERVAL 12 MONTH) <= LEAST(COALESCE(p.regenddate, pr.lcd), pr.lcd);

CREATE TABLE v_patient_linked AS
SELECT
  p.patid,
  p.pracid,
  p.regstartdate,
  p.regenddate,
  p.gender,
  p.yob_date,
  p.lcd,
  p.cprd_death,
  od.reg_date_of_death AS ons_death,
  COALESCE(od.reg_date_of_death, p.cprd_death) AS merged_death,
  le.hes_apc_e,
  le.hes_op_e,
  le.ons_death_e,
  le.lsoa_e,
  er.ethnic_6,
  pracid_imd.e2015_imd_10,
  patid_imd.e2019_imd_20 AS patid_imd,
  le.linkyear
FROM
  v_patient_base_eligible AS p
  LEFT JOIN practice AS pr ON pr.pracid = p.pracid
  LEFT JOIN linkage_eligibility AS le ON le.patid = p.patid
  LEFT JOIN ethnicity_record AS er ON er.patid = p.patid
  LEFT JOIN practice_imd AS pracid_imd ON pracid_imd.pracid = p.pracid
  LEFT JOIN patient_2019_imd AS patid_imd ON patid_imd.patid = p.patid
  LEFT JOIN death_patient_deduplicated AS od ON od.patid = p.patid
WHERE
  CAST(pr.region AS UNSIGNED) BETWEEN 1 AND 9;

-- only want english practices
CREATE TABLE v_patient_earliest_4_latest_2 AS
SELECT
  p.patid,
  p.pracid,
  p.regstartdate,
  p.regenddate,
  p.gender,
  p.yob_date,
  p.cprd_death,
  p.ons_death,
  p.merged_death,
  p.hes_apc_e,
  p.hes_op_e,
  p.ons_death_e,
  p.lsoa_e,
  p.ethnic_6,
  p.e2015_imd_10,
  p.patid_imd,
  p.linkyear,
  DATE '1998-01-02' AS ons_link_start, -- ons linkage start - study beginning 
  DATE '2025-05-30' AS ons_link_end,
  LEAST(
    COALESCE(p.lcd, DATE '9999-12-31'),
    COALESCE(p.regenddate, DATE '9999-12-31'),
    COALESCE(p.merged_death, DATE '9999-12-31'),
    DATE '2024-06-24' -- max lcd of all practices (select max(lcd) from practice;) - study end
  ) AS earliest_4,
  GREATEST(
    COALESCE(p.regstartdate, DATE '1000-01-01'),
    DATE '1998-01-02' -- ons linkage start - study beginning 
  ) AS latest_2
FROM
  v_patient_linked AS p;

CREATE INDEX idx_patid ON v_patient_earliest_4_latest_2 (patid);

-- Find first candidate diagnosis (including mci) occurring after age of 18
CREATE TABLE v_candidate_first_diagnosis AS
SELECT
  d.patid,
  MIN(d.dementia_mci_eventdate) AS first_diag_mci_dementia
FROM
  candidate_patids AS d -- mci included as dementia code
  INNER JOIN v_patient_earliest_4_latest_2 AS p ON p.patid = d.patid
WHERE
  -- dementia_event after 18 years old (remove observations that occur during the year 1899/1860)
  d.dementia_mci_eventdate > DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
GROUP BY
  d.patid;

CREATE INDEX idx_patid ON v_candidate_first_diagnosis (patid);

CREATE TABLE preproc_patient_candidates AS
SELECT
  p.patid,
  p.pracid,
  p.regstartdate,
  p.regenddate,
  p.gender,
  p.yob_date,
  p.cprd_death,
  p.ons_death,
  p.merged_death,
  p.hes_apc_e,
  p.hes_op_e,
  p.ons_death_e,
  p.lsoa_e,
  p.ethnic_6,
  p.e2015_imd_10,
  p.patid_imd,
  p.linkyear,
  p.ons_link_start,
  p.ons_link_end,
  p.earliest_4,
  p.latest_2,
  d.first_diag_mci_dementia,
  YEAR(d.first_diag_mci_dementia) - YEAR(p.yob_date) AS age_at_first_diag_mci_dementia
FROM
  v_patient_earliest_4_latest_2 AS p
  INNER JOIN v_candidate_first_diagnosis AS d ON d.patid = p.patid
WHERE
  d.first_diag_mci_dementia >= DATE_ADD(p.yob_date, INTERVAL 40 YEAR)
  AND d.first_diag_mci_dementia <= DATE_ADD(p.yob_date, INTERVAL 100 YEAR)
  -- remove patients with first dementia/mci diagnosis before the age of 40 and after 100
  AND (
    p.merged_death IS NULL
    OR DATE_ADD(p.regstartdate, INTERVAL 12 MONTH) <= p.merged_death -- in practice for at least a 1 year part 2 (merged_death instead of lcd in part 1)
  )
  AND (
    p.regstartdate IS NULL
    OR p.yob_date IS NULL
    OR p.regstartdate <= DATE_ADD(p.yob_date, INTERVAL 100 YEAR)
    -- first reg less than 100 years old
  )
  AND (
    p.regstartdate IS NULL
    OR p.regstartdate >= DATE '1900-01-01'
    -- first reg before 1900-01-01 (redundant by prior step - keep for now)
    AND p.hes_apc_e = 1
    AND p.hes_op_e = 1
    AND p.ons_death_e = 1
    AND p.lsoa_e = 1
  );

CREATE INDEX idx_patid ON preproc_patient_candidates (patid);

CREATE TABLE v_qc_patient_pipeline_counts AS
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
  'v_patient_earliest_4_latest_2',
  COUNT(*),
  COUNT(DISTINCT patid)
FROM
  v_patient_earliest_4_latest_2
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

CREATE TABLE v_qc_patient_exclusions AS
SELECT
  (
    SELECT
      COUNT(*)
    FROM
      patient
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
      v_patient_earliest_4_latest_2
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
