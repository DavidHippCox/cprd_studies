-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
--
-- Mild cognitive impairment codes are excluded at source.
--
-- Specificity values:
--   1 = unspecified dementia
--   2 = specified dementia subtype
USE aurum_oxcprd_001b;

/* -------------------------------------------------------------------------
1. Dementia event sources
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS dementia_event_sources;

CREATE TABLE dementia_event_sources (
  source_id TINYINT UNSIGNED NOT NULL,
  source_table VARCHAR(64) NOT NULL,
  source_dataset VARCHAR(4) NOT NULL,
  source_priority TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (source_id),
  UNIQUE KEY uq_dementia_event_source_table (source_table),
  CHECK (source_dataset IN ('cprd', 'hes'))
) ENGINE = InnoDB;

INSERT INTO
  dementia_event_sources (source_id, source_table, source_dataset, source_priority)
VALUES
  (1, 'dementia_observation', 'cprd', 2),
  (2, 'dementia_drug_drugissue', 'cprd', 2),
  (3, 'hes_apc_diag_epi', 'hes', 1),
  (4, 'hes_apc_diag_hosp', 'hes', 1),
  (5, 'hes_apc_primary_diag_hosp', 'hes', 1),
  (6, 'hes_op', 'hes', 1);

/* -------------------------------------------------------------------------
2. Compact dementia event table
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS preproc_dementia_events;

CREATE TABLE preproc_dementia_events (
  patid BIGINT UNSIGNED NOT NULL,
  eventdate DATE NOT NULL,
  source_id TINYINT UNSIGNED NOT NULL,
  medcodeid BIGINT UNSIGNED NULL,
  icd10 VARCHAR(9) NULL,
  specificity TINYINT UNSIGNED NOT NULL,
  CHECK (specificity IN (1, 2))
) ENGINE = InnoDB;

/* CPRD observations */
INSERT INTO
  preproc_dementia_events (patid, eventdate, source_id, medcodeid, icd10, specificity)
SELECT
  o.patid,
  o.obsdate,
  1,
  o.medcodeid,
  NULL,
  CASE
    WHEN LOWER(TRIM(c.subtype)) = 'unspecified' THEN 1
    ELSE 2
  END
FROM
  dementia_observation AS o
  INNER JOIN v0_dementia_codes_AURUM AS c ON c.medcodeid = o.medcodeid
  INNER JOIN preproc_patient_candidates AS p ON p.patid = o.patid
WHERE
  o.obsdate IS NOT NULL
  AND o.obsdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR) -- observations after 18 years old
  AND COALESCE(LOWER(TRIM(c.subtype)), '') <> 'mild cognitive impairment'
  AND o.obstypeid <> 4;

INSERT INTO
  preproc_dementia_events (patid, eventdate, source_id, medcodeid, icd10, specificity)
SELECT
  d.patid,
  d.issuedate,
  2,
  NULL,
  NULL,
  1
FROM
  dementia_drug_drugissue AS d
  INNER JOIN v0_dementia_drug_AURUM AS c ON c.prodcodeid = d.prodcodeid
  INNER JOIN preproc_patient_candidates AS p ON p.patid = d.patid
WHERE
  d.issuedate IS NOT NULL
  AND d.issuedate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR);

/* HES APC episode diagnoses */
INSERT INTO
  preproc_dementia_events (patid, eventdate, source_id, medcodeid, icd10, specificity)
SELECT
  h.patid,
  h.epistart,
  3,
  NULL,
  h.ICD,
  CASE
    WHEN LOWER(TRIM(c.subtype)) = 'unspecified' THEN 1
    ELSE 2
  END
FROM
  dementia_hes_diagnosis_epi AS h
  INNER JOIN dementia_codes_icd10 AS c ON c.icd10 = h.ICD
  INNER JOIN preproc_patient_candidates AS p ON p.patid = h.patid
WHERE
  h.epistart IS NOT NULL
  AND h.epistart >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
  AND COALESCE(LOWER(TRIM(c.subtype)), '') <> 'mild cognitive impairment';

/* HES APC hospital diagnoses */
INSERT INTO
  preproc_dementia_events (patid, eventdate, source_id, medcodeid, icd10, specificity)
SELECT
  h.patid,
  h.admidate,
  4,
  NULL,
  h.ICD,
  CASE
    WHEN LOWER(TRIM(c.subtype)) = 'unspecified' THEN 1
    ELSE 2
  END
FROM
  dementia_hes_diagnosis_hosp AS h
  INNER JOIN dementia_codes_icd10 AS c ON c.icd10 = h.ICD
  INNER JOIN preproc_patient_candidates AS p ON p.patid = h.patid
WHERE
  h.admidate IS NOT NULL
  AND h.admidate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
  AND COALESCE(LOWER(TRIM(c.subtype)), '') <> 'mild cognitive impairment';

/* HES APC primary hospital diagnoses */
INSERT INTO
  preproc_dementia_events (patid, eventdate, source_id, medcodeid, icd10, specificity)
SELECT
  h.patid,
  h.admidate,
  5,
  NULL,
  h.ICD_PRIMARY,
  CASE
    WHEN LOWER(TRIM(c.subtype)) = 'unspecified' THEN 1
    ELSE 2
  END
FROM
  dementia_hes_primary_diag_hosp AS h
  INNER JOIN dementia_codes_icd10 AS c ON c.icd10 = h.ICD_PRIMARY
  INNER JOIN preproc_patient_candidates AS p ON p.patid = h.patid
WHERE
  h.admidate IS NOT NULL
  AND h.admidate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
  AND COALESCE(LOWER(TRIM(c.subtype)), '') <> 'mild cognitive impairment';

/* HES outpatient diagnoses */
INSERT INTO
  preproc_dementia_events (patid, eventdate, source_id, medcodeid, icd10, specificity)
SELECT
  h.patid,
  h.apptdate,
  6,
  NULL,
  h.icd,
  CASE
    WHEN LOWER(TRIM(c.subtype)) = 'unspecified' THEN 1
    ELSE 2
  END
FROM
  dementia_hesop_clinical_apptdate AS h
  INNER JOIN dementia_codes_icd10 AS c ON c.icd10 = h.icd
  INNER JOIN preproc_patient_candidates AS p ON p.patid = h.patid
WHERE
  h.apptdate IS NOT NULL
  AND h.apptdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
  AND COALESCE(LOWER(TRIM(c.subtype)), '') <> 'mild cognitive impairment';

-- Cover first-date selection and same-day source resolution.
ALTER TABLE preproc_dementia_events
ADD INDEX idx_dementia_events_patient_date (patid, eventdate, specificity, source_id);

/* -------------------------------------------------------------------------
3. Source-level QC
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS qc_dementia_event_counts;

CREATE TABLE qc_dementia_event_counts AS
SELECT
  s.source_dataset,
  s.source_table,
  COUNT(*) AS n_records,
  COUNT(DISTINCT e.patid) AS n_patients
FROM
  preproc_dementia_events AS e
  INNER JOIN dementia_event_sources AS s ON s.source_id = e.source_id
GROUP BY
  s.source_dataset,
  s.source_table;
