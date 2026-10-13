-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- this was used to create table 1 v1
--
--
-- Defintions
--   1. Observations are after age 18 
--   2. Exclude family-history observations (obstypeid = 4).
--   3. Observations on index day are defined to be before 
--      cohort entry/dementia index date and are included
--   4. Record any adult dementia-drug issue within the inclusive interval
--      [latest_2, earliest_4], independently of the dementia index date.
--   5. A missing baseline event has a NULL date. Dementia-drug flags are
--      1 for any qualifying issue and 0 when none is recorded.
--
USE aurum_oxcprd_001b;

/* ----------------------------------------------------------------------
1. Narrow, indexed, session-scoped code maps
------------------------------------------------------------------------ */
DROP TEMPORARY TABLE IF EXISTS tmp_descriptive_disease_map;

CREATE TEMPORARY TABLE tmp_descriptive_disease_map (
  feature VARCHAR(32) NOT NULL,
  medcodeid BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (feature, medcodeid),
  INDEX idx_descriptive_disease_code (medcodeid)
) ENGINE = InnoDB;

INSERT INTO
  tmp_descriptive_disease_map (feature, medcodeid)
SELECT
  'type2_diabetes',
  c.medcodeid
FROM
  v0_diabetes_all_codes_aurum AS c
WHERE
  c.medcodeid IS NOT NULL
  AND c.category = 'type 2'
UNION
SELECT
  'hypertension',
  c.medcodeid
FROM
  v0_hypertension_codes_aurum AS c
WHERE
  c.medcodeid IS NOT NULL
UNION
SELECT
  'ihd',
  c.medcodeid
FROM
  v0_ihd_codes_aurum AS c
WHERE
  c.medcodeid IS NOT NULL
UNION
SELECT
  'wernicke_encephalopathy',
  c.medcodeid
FROM
  v0_wenicke_encephalopathy_codes_aurum AS c
WHERE
  c.medcodeid IS NOT NULL
UNION
SELECT
  'arld',
  c.medcodeid
FROM
  v1_arld_codes_AURUM AS c
WHERE
  c.medcodeid IS NOT NULL;

DROP TEMPORARY TABLE IF EXISTS tmp_descriptive_thiamine_map;

CREATE TEMPORARY TABLE tmp_descriptive_thiamine_map (prodcodeid BIGINT UNSIGNED NOT NULL, PRIMARY KEY (prodcodeid)) ENGINE = InnoDB;

INSERT INTO
  tmp_descriptive_thiamine_map (prodcodeid)
SELECT DISTINCT
  c.prodcodeid
FROM
  v0_thiamine_drug_aurum AS c
WHERE
  c.prodcodeid IS NOT NULL;

DROP TEMPORARY TABLE IF EXISTS tmp_descriptive_dementia_drug_map;

CREATE TEMPORARY TABLE tmp_descriptive_dementia_drug_map (
  drugtype VARCHAR(16) NOT NULL,
  prodcodeid BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (drugtype, prodcodeid),
  INDEX idx_descriptive_dementia_drug_code (prodcodeid)
) ENGINE = InnoDB;

INSERT INTO
  tmp_descriptive_dementia_drug_map (drugtype, prodcodeid)
SELECT DISTINCT
  c.drugtypes,
  c.prodcodeid
FROM
  v0_dementia_drug_AURUM AS c
WHERE
  c.prodcodeid IS NOT NULL
  AND c.drugtypes IN ('Donepezil', 'Rivastigmine', 'Galantamine', 'Memantine');

/* ----------------------------------------------------------------------
2. Aggregate eligible dates and drug occurrences by patient
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS preproc_patient_descriptives_dementia;

CREATE TABLE preproc_patient_descriptives_dementia ENGINE = InnoDB AS
WITH
  disease_dates AS (
    SELECT
      p.patid,
      MIN(
        CASE
          WHEN m.feature = 'type2_diabetes' THEN o.obsdate
        END
      ) AS type2_diabetes_eventdate,
      MIN(
        CASE
          WHEN m.feature = 'hypertension' THEN o.obsdate
        END
      ) AS hypertension_eventdate,
      MIN(
        CASE
          WHEN m.feature = 'ihd' THEN o.obsdate
        END
      ) AS ihd_eventdate,
      MIN(
        CASE
          WHEN m.feature = 'wernicke_encephalopathy' THEN o.obsdate
        END
      ) AS wernicke_encephalopathy_eventdate,
      MIN(
        CASE
          WHEN m.feature = 'arld' THEN o.obsdate
        END
      ) AS arld_eventdate
    FROM
      analysis_pop AS p
      INNER JOIN observation AS o ON o.patid = p.patid
      AND o.obsdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
      AND o.obsdate <= p.dementia_index_date
      INNER JOIN tmp_descriptive_disease_map AS m ON m.medcodeid = o.medcodeid
    WHERE
      o.obstypeid <> 4
    GROUP BY
      p.patid
  ),
  thiamine_dates AS (
    SELECT
      p.patid,
      MIN(d.issuedate) AS thiamine_eventdate
    FROM
      analysis_pop AS p
      INNER JOIN drugissue AS d ON d.patid = p.patid
      AND d.issuedate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
      AND d.issuedate <= p.dementia_index_date
      INNER JOIN tmp_descriptive_thiamine_map AS m ON m.prodcodeid = d.prodcodeid
    GROUP BY
      p.patid
  ),
  dementia_drug_flags AS (
    SELECT
      p.patid,
      MAX(
        CASE
          WHEN m.drugtype = 'Donepezil' THEN 1
          ELSE 0
        END
      ) AS donepezil_flag,
      MAX(
        CASE
          WHEN m.drugtype = 'Rivastigmine' THEN 1
          ELSE 0
        END
      ) AS rivastigmine_flag,
      MAX(
        CASE
          WHEN m.drugtype = 'Galantamine' THEN 1
          ELSE 0
        END
      ) AS galantamine_flag,
      MAX(
        CASE
          WHEN m.drugtype = 'Memantine' THEN 1
          ELSE 0
        END
      ) AS memantine_flag
    FROM
      analysis_pop AS p
      INNER JOIN dementia_drug_drugissue AS d ON d.patid = p.patid
      AND d.issuedate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
      AND d.issuedate >= p.latest_2
      AND d.issuedate <= p.earliest_4
      INNER JOIN tmp_descriptive_dementia_drug_map AS m ON m.prodcodeid = d.prodcodeid
    GROUP BY
      p.patid
  )
SELECT
  p.patid,
  p.dementia_index_date,
  h.type2_diabetes_eventdate,
  h.hypertension_eventdate,
  h.ihd_eventdate,
  t.thiamine_eventdate,
  h.wernicke_encephalopathy_eventdate,
  h.arld_eventdate,
  COALESCE(d.donepezil_flag, 0) AS donepezil_flag,
  COALESCE(d.rivastigmine_flag, 0) AS rivastigmine_flag,
  COALESCE(d.galantamine_flag, 0) AS galantamine_flag,
  COALESCE(d.memantine_flag, 0) AS memantine_flag
FROM
  analysis_pop AS p
  LEFT JOIN disease_dates AS h ON h.patid = p.patid
  LEFT JOIN thiamine_dates AS t ON t.patid = p.patid
  LEFT JOIN dementia_drug_flags AS d ON d.patid = p.patid;

ALTER TABLE preproc_patient_descriptives_dementia
ADD PRIMARY KEY (patid),
ADD INDEX idx_patient_descriptives_dementia_date (dementia_index_date);

/* ----------------------------------------------------------------------
3. QC: one-row patient counts
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS qc_patient_descriptives_dementia_counts;

CREATE TABLE qc_patient_descriptives_dementia_counts ENGINE = InnoDB AS
SELECT
  COUNT(*) AS n_analysis_patients,
  COUNT(type2_diabetes_eventdate) AS n_with_type2_diabetes,
  COUNT(hypertension_eventdate) AS n_with_hypertension,
  COUNT(ihd_eventdate) AS n_with_ihd,
  COUNT(thiamine_eventdate) AS n_with_thiamine,
  COUNT(wernicke_encephalopathy_eventdate) AS n_with_wernicke_encephalopathy,
  COUNT(arld_eventdate) AS n_with_arld,
  COALESCE(SUM(donepezil_flag), 0) AS n_with_donepezil,
  COALESCE(SUM(rivastigmine_flag), 0) AS n_with_rivastigmine,
  COALESCE(SUM(galantamine_flag), 0) AS n_with_galantamine,
  COALESCE(SUM(memantine_flag), 0) AS n_with_memantine
FROM
  preproc_patient_descriptives_dementia;

/* ----------------------------------------------------------------------
4. Cleanup
------------------------------------------------------------------------ */
DROP TEMPORARY TABLE IF EXISTS tmp_descriptive_disease_map;

DROP TEMPORARY TABLE IF EXISTS tmp_descriptive_thiamine_map;

DROP TEMPORARY TABLE IF EXISTS tmp_descriptive_dementia_drug_map;
