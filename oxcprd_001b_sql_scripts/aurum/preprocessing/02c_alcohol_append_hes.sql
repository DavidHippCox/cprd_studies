-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
-- 02c. Append HES AUD events to classified CPRD alcohol observations
--
--
-- HES AUD events:
-- We are only using 'aud' codes from hes i.e not F10.0 (accute intoxication)
-- future work should consider potential exclusion of patients if highest
-- alcohol recording before indexdate (dementia incidence) 
-- is lower than heavy-drinker status 
--
USE aurum_oxcprd_001b;

/* -------------------------------------------------------------------------
1. Combine classified CPRD observations with HES AUD events
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS aurum_oxcprd_001b.preproc_alcohol_events;

CREATE TABLE aurum_oxcprd_001b.preproc_alcohol_events ENGINE = InnoDB AS
WITH
  aud_codes_icd10 AS (
    SELECT
      icd10,
      `description` AS term,
      strict_phenotype
    FROM
      alcohol_codes_icd10
    WHERE
      icd10 IS NOT NULL
      AND icd10 <> ''
      -- Do not include acute intoxication.
      AND icd10 <> 'F10.0'
  ),
  alcohol_events AS (
    /* ---------------------------------------------------------------------
    CPRD: already classified alcohol observations
    --------------------------------------------------------------------- */
    SELECT
      c.source_table,
      'cprd' AS source_dataset,
      c.patid,
      c.eventdate,
      c.medcodeid,
      CAST(NULL AS CHAR(9)) AS icd10,
      c.term,
      c.strict_phenotype,
      c.alc_category,
      c.alc_category_status,
      c.alc_category_reject_reason
    FROM
      aurum_oxcprd_001b.alcohol_observation_category_classified AS c
    UNION ALL
    /* ---------------------------------------------------------------------
    HES APC: episode diagnoses
    --------------------------------------------------------------------- */
    SELECT
      'hes_apc_diag_epi' AS source_table,
      'hes' AS source_dataset,
      h.patid,
      h.epistart AS eventdate,
      CAST(NULL AS UNSIGNED) AS medcodeid,
      h.icd AS icd10,
      il.term,
      il.strict_phenotype,
      'aud' AS alc_category,
      'ACCEPT' AS alc_category_status,
      CAST(NULL AS CHAR(255)) AS alc_category_reject_reason
    FROM
      alcohol_hes_diagnosis_epi AS h
      INNER JOIN aud_codes_icd10 AS il ON il.icd10 = h.icd
    UNION ALL
    /* ---------------------------------------------------------------------
    HES APC: hospital diagnoses
    --------------------------------------------------------------------- */
    SELECT
      'hes_apc_diag_hosp' AS source_table,
      'hes' AS source_dataset,
      h.patid,
      h.admidate AS eventdate,
      CAST(NULL AS UNSIGNED) AS medcodeid,
      h.icd AS icd10,
      il.term,
      il.strict_phenotype,
      'aud' AS alc_category,
      'ACCEPT' AS alc_category_status,
      CAST(NULL AS CHAR(255)) AS alc_category_reject_reason
    FROM
      alcohol_hes_diagnosis_hosp AS h
      INNER JOIN aud_codes_icd10 AS il ON il.icd10 = h.icd
    UNION ALL
    /* ---------------------------------------------------------------------
    HES APC: primary hospital diagnosis
    --------------------------------------------------------------------- */
    SELECT
      'hes_apc_primary_diag_hosp' AS source_table,
      'hes' AS source_dataset,
      h.patid,
      h.admidate AS eventdate,
      CAST(NULL AS UNSIGNED) AS medcodeid,
      h.icd_primary AS icd10,
      il.term,
      il.strict_phenotype,
      'aud' AS alc_category,
      'ACCEPT' AS alc_category_status,
      CAST(NULL AS CHAR(255)) AS alc_category_reject_reason
    FROM
      alcohol_hes_primary_diag_hosp AS h
      INNER JOIN aud_codes_icd10 AS il ON il.icd10 = h.icd_primary
    UNION ALL
    /* ---------------------------------------------------------------------
    HES outpatient
    --------------------------------------------------------------------- */
    SELECT
      'hes_op' AS source_table,
      'hes' AS source_dataset,
      h.patid,
      h.apptdate AS eventdate,
      CAST(NULL AS UNSIGNED) AS medcodeid,
      h.icd AS icd10,
      il.term,
      il.strict_phenotype,
      'aud' AS alc_category,
      'ACCEPT' AS alc_category_status,
      CAST(NULL AS CHAR(255)) AS alc_category_reject_reason
    FROM
      alcohol_hesop_clinical_apptdate AS h
      INNER JOIN aud_codes_icd10 AS il ON il.icd10 = h.icd
  )
SELECT
  e.source_table,
  e.source_dataset,
  e.patid,
  e.eventdate,
  e.medcodeid,
  e.icd10,
  e.term,
  e.strict_phenotype,
  e.alc_category,
  e.alc_category_status,
  e.alc_category_reject_reason
FROM
  alcohol_events AS e
  INNER JOIN preproc_patient_candidates AS p ON p.patid = e.patid
WHERE
  e.eventdate IS NOT NULL
  AND p.yob_date IS NOT NULL
  AND e.eventdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR) -- remove weird obervations that occur in 1899 & only adult observations. 
  -- only observations up to earliest of {death, lcd, study end, regenddate}
  AND e.eventdate <= earliest_4;

ALTER TABLE aurum_oxcprd_001b.preproc_alcohol_events
ORDER BY
  patid,
  eventdate;

ALTER TABLE aurum_oxcprd_001b.preproc_alcohol_events
ADD INDEX idx_alcohol_events_patid_eventdate (patid, eventdate),
ADD INDEX idx_alcohol_events_source (source_dataset, source_table),
ADD INDEX idx_alcohol_events_medcodeid (medcodeid),
ADD INDEX idx_alcohol_events_icd10 (icd10),
ADD INDEX idx_alcohol_events_category (alc_category);

/* -------------------------------------------------------------------------
2. QC summary
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS aurum_oxcprd_001b.qc_alcohol_event_counts;

CREATE TABLE aurum_oxcprd_001b.qc_alcohol_event_counts AS
SELECT
  source_dataset,
  source_table,
  alc_category,
  alc_category_status,
  COUNT(*) AS n_rows,
  COUNT(DISTINCT patid) AS n_patients
FROM
  aurum_oxcprd_001b.preproc_alcohol_events
GROUP BY
  source_dataset,
  source_table,
  alc_category,
  alc_category_status;
