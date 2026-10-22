-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
--
-- Defintions
--   1. Observations are after age 18 
--   2. Exclude family-history observations (obstypeid = 4).
--   3. Observations on index day are defined to be before 
--      cohort entry/dementia index date and are included
--   4. For table 1 v1 we apply no exclusion windows around dementia_index_date.
USE aurum_oxcprd_001b;

/* ----------------------------------------------------------------------
1. Unify the three Aurum codelists
------------------------------------------------------------------------ */
DROP TEMPORARY TABLE IF EXISTS tmp_confounder_code_map;

CREATE TEMPORARY TABLE tmp_confounder_code_map (
  confounder_name VARCHAR(32) NOT NULL,
  medcodeid BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (confounder_name, medcodeid),
  INDEX idx_tmp_confounder_code (medcodeid)
) ENGINE = InnoDB;

INSERT INTO
  tmp_confounder_code_map (confounder_name, medcodeid)
SELECT
  'depression_anxiety',
  c.medcodeid
FROM
  v0_depression_anxiety_codes_AURUM AS c
UNION ALL
SELECT
  'smi',
  c.medcodeid
FROM
  v0_smi_codes_AURUM AS c
UNION ALL
SELECT
  'tbi',
  c.medcodeid
FROM
  v0_tbi_codes_AURUM AS c;

/* ----------------------------------------------------------------------
2. Select first observations before and after the dementia index date
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS preproc_patient_confounders_dementia;

CREATE TABLE preproc_patient_confounders_dementia ENGINE = InnoDB AS
WITH
  first_events AS (
    SELECT
      p.patid,
      MIN(
        CASE
          WHEN c.confounder_name = 'depression_anxiety'
          AND o.obsdate <= p.dementia_index_date THEN o.obsdate
        END
      ) AS confounder_dep_anx_eventdate,
      MIN(
        CASE
          WHEN c.confounder_name = 'depression_anxiety'
          AND o.obsdate > p.dementia_index_date THEN o.obsdate
        END
      ) AS post_index_dep_anx_eventdate,
      MIN(
        CASE
          WHEN c.confounder_name = 'smi'
          AND o.obsdate <= p.dementia_index_date THEN o.obsdate
        END
      ) AS confounder_smi_eventdate,
      MIN(
        CASE
          WHEN c.confounder_name = 'smi'
          AND o.obsdate > p.dementia_index_date THEN o.obsdate
        END
      ) AS post_index_smi_eventdate,
      MIN(
        CASE
          WHEN c.confounder_name = 'tbi'
          AND o.obsdate <= p.dementia_index_date THEN o.obsdate
        END
      ) AS confounder_tbi_eventdate,
      MIN(
        CASE
          WHEN c.confounder_name = 'tbi'
          AND o.obsdate > p.dementia_index_date THEN o.obsdate
        END
      ) AS post_index_tbi_eventdate
    FROM
      analysis_pop AS p
      INNER JOIN observation AS o ON o.patid = p.patid
      AND o.obsdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
      INNER JOIN tmp_confounder_code_map AS c ON c.medcodeid = o.medcodeid
    WHERE
      o.obstypeid <> 4
    GROUP BY
      p.patid
  )
SELECT
  p.patid,
  p.dementia_index_date,
  f.confounder_dep_anx_eventdate,
  f.post_index_dep_anx_eventdate,
  f.confounder_smi_eventdate,
  f.post_index_smi_eventdate,
  f.confounder_tbi_eventdate,
  f.post_index_tbi_eventdate
FROM
  analysis_pop AS p
  LEFT JOIN first_events AS f ON f.patid = p.patid;

ALTER TABLE preproc_patient_confounders_dementia
ADD PRIMARY KEY (patid),
ADD INDEX idx_patient_confounders_dementia_date (dementia_index_date);

/* ----------------------------------------------------------------------
3. QC
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS qc_patient_confounders_dementia_counts;

CREATE TABLE qc_patient_confounders_dementia_counts ENGINE = InnoDB AS
SELECT
  COUNT(*) AS n_analysis_patients,
  COUNT(confounder_dep_anx_eventdate) AS n_confounder_dep_anx,
  COUNT(post_index_dep_anx_eventdate) AS n_post_index_dep_anx,
  COUNT(confounder_smi_eventdate) AS n_confounder_smi,
  COUNT(post_index_smi_eventdate) AS n_post_index_smi,
  COUNT(confounder_tbi_eventdate) AS n_confounder_tbi,
  COUNT(post_index_tbi_eventdate) AS n_post_index_tbi
FROM
  preproc_patient_confounders_dementia;

DROP TEMPORARY TABLE IF EXISTS tmp_confounder_code_map;
