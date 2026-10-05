-- 04. Depression/anxiety, SMI, and TBI confounders for CPRD Aurum.
--
-- Run after:
--   03b_patient_alcohol_dementia.sql
--
-- Depends on:
--   observation
--   preproc_patient_alcohol_dementia
--   v0_depression_anxiety_codes_AURUM
--   v0_smi_codes_AURUM
--   v0_tbi_codes_AURUM
--
-- Rules:
--   1. Use adult observations on or before the dementia index date.
--   2. Exclude family-history observations (obstypeid = 4).
--   3. Select the earliest retained observation for each patient and
--      confounder.
--   4. Classify the selected observation into one of two windows:
--        confounder : eventdate < index date - 1095 days
--        exclusion  : eventdate >= index date - 1095 days
--                     and eventdate <= index date
--   5. Do not extract or classify post-dementia observations.
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

INSERT INTO tmp_confounder_code_map (
  confounder_name,
  medcodeid
)
SELECT
  'depression_anxiety',
  c.medcodeid
FROM
  v0_depression_anxiety_codes_AURUM AS c
WHERE
  c.medcodeid IS NOT NULL

UNION ALL

SELECT
  'smi',
  c.medcodeid
FROM
  v0_smi_codes_AURUM AS c
WHERE
  c.medcodeid IS NOT NULL

UNION ALL

SELECT
  'tbi',
  c.medcodeid
FROM
  v0_tbi_codes_AURUM AS c
WHERE
  c.medcodeid IS NOT NULL;

/* ----------------------------------------------------------------------
2. Select and classify the earliest pre-index observation
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS preproc_patient_confounders_dementia;

CREATE TABLE preproc_patient_confounders_dementia ENGINE = InnoDB AS
WITH
  ranked_events AS (
    SELECT
      p.patid,
      p.dementia_index_date,
      c.confounder_name,
      o.obsdate AS eventdate,
      ROW_NUMBER() OVER (
        PARTITION BY
          p.patid,
          c.confounder_name
        ORDER BY
          o.obsdate,
          o.medcodeid,
          o.obsid
      ) AS event_rank
    FROM
      preproc_patient_alcohol_dementia AS p
      INNER JOIN observation AS o ON o.patid = p.patid
      AND o.obsdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
      AND o.obsdate <= p.dementia_index_date
      INNER JOIN tmp_confounder_code_map AS c ON c.medcodeid = o.medcodeid
    WHERE
      o.obstypeid <> 4
  ),
  first_events AS (
    SELECT
      e.patid,
      e.confounder_name,
      e.eventdate,
      CASE
        WHEN e.eventdate < DATE_SUB(
          e.dementia_index_date,
          INTERVAL 1095 DAY
        ) THEN 'confounder'
        ELSE 'exclusion'
      END AS event_window
    FROM
      ranked_events AS e
    WHERE
      e.event_rank = 1
  )
SELECT
  p.patid,
  p.dementia_index_date,
  MAX(
    CASE
      WHEN f.confounder_name = 'depression_anxiety'
      AND f.event_window = 'confounder' THEN 1
      ELSE 0
    END
  ) AS confounder_dep_anx,
  MAX(
    CASE
      WHEN f.confounder_name = 'depression_anxiety'
      AND f.event_window = 'confounder' THEN f.eventdate
    END
  ) AS confounder_dep_anx_eventdate,
  MAX(
    CASE
      WHEN f.confounder_name = 'depression_anxiety'
      AND f.event_window = 'exclusion' THEN 1
      ELSE 0
    END
  ) AS exclusion_dep_anx,
  MAX(
    CASE
      WHEN f.confounder_name = 'depression_anxiety'
      AND f.event_window = 'exclusion' THEN f.eventdate
    END
  ) AS exclusion_dep_anx_eventdate,
  MAX(
    CASE
      WHEN f.confounder_name = 'smi'
      AND f.event_window = 'confounder' THEN 1
      ELSE 0
    END
  ) AS confounder_smi,
  MAX(
    CASE
      WHEN f.confounder_name = 'smi'
      AND f.event_window = 'confounder' THEN f.eventdate
    END
  ) AS confounder_smi_eventdate,
  MAX(
    CASE
      WHEN f.confounder_name = 'smi'
      AND f.event_window = 'exclusion' THEN 1
      ELSE 0
    END
  ) AS exclusion_smi,
  MAX(
    CASE
      WHEN f.confounder_name = 'smi'
      AND f.event_window = 'exclusion' THEN f.eventdate
    END
  ) AS exclusion_smi_eventdate,
  MAX(
    CASE
      WHEN f.confounder_name = 'tbi'
      AND f.event_window = 'confounder' THEN 1
      ELSE 0
    END
  ) AS confounder_tbi,
  MAX(
    CASE
      WHEN f.confounder_name = 'tbi'
      AND f.event_window = 'confounder' THEN f.eventdate
    END
  ) AS confounder_tbi_eventdate,
  MAX(
    CASE
      WHEN f.confounder_name = 'tbi'
      AND f.event_window = 'exclusion' THEN 1
      ELSE 0
    END
  ) AS exclusion_tbi,
  MAX(
    CASE
      WHEN f.confounder_name = 'tbi'
      AND f.event_window = 'exclusion' THEN f.eventdate
    END
  ) AS exclusion_tbi_eventdate
FROM
  preproc_patient_alcohol_dementia AS p
  LEFT JOIN first_events AS f ON f.patid = p.patid
GROUP BY
  p.patid,
  p.dementia_index_date;

ALTER TABLE preproc_patient_confounders_dementia
ADD PRIMARY KEY (patid),
ADD INDEX idx_patient_confounders_dementia_date (dementia_index_date);

/* ----------------------------------------------------------------------
3. QC
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS qc_patient_confounders_dementia_counts;

CREATE TABLE qc_patient_confounders_dementia_counts ENGINE = InnoDB AS
SELECT
  COUNT(*) AS n_dementia_patients,
  SUM(confounder_dep_anx) AS n_confounder_dep_anx,
  SUM(exclusion_dep_anx) AS n_exclusion_dep_anx,
  SUM(confounder_smi) AS n_confounder_smi,
  SUM(exclusion_smi) AS n_exclusion_smi,
  SUM(confounder_tbi) AS n_confounder_tbi,
  SUM(exclusion_tbi) AS n_exclusion_tbi
FROM
  preproc_patient_confounders_dementia;

DROP TEMPORARY TABLE IF EXISTS tmp_confounder_code_map;
