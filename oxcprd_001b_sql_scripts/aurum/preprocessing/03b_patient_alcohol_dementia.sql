-- 03b. Summarise alcohol phenotype before the dementia index date
--
-- Depends on:
--   preproc_alcohol_events (created by 02c_alcohol_append_hes.sql)
--   dementia_index (created by 03a_dementia_index.sql)
--   dementia_index_mixed (created by 03a_dementia_index.sql)
--   preproc_patient_candidates (created by 01_patient.sql)
--
-- Rules:
--   1. Include accepted alcohol events on or before the index date.
--   2. Summarise alc_category and alc_category_2 separately.
--   3. The final year is inclusive of index date - 1 year and index date.
--   4. Reverse causation is flagged when the final-year maximum is higher
--      than the maximum recorded before the final year. Both periods must
--      contain a classified event.
--   5. Alcohol dementia includes subtype Alcohol and Mixed indices that
--      contain an Alcohol subtype.
--   6. Retain every patient in dementia_index, including patients without
--      an accepted alcohol event.
--   7. Carry the adult-history and follow-up boundaries needed by downstream
--      cohort analyses, avoiding repeated joins to patient candidates.
USE aurum_oxcprd_001b;

DROP TABLE IF EXISTS preproc_patient_alcohol_dementia;

CREATE TABLE preproc_patient_alcohol_dementia ENGINE = InnoDB AS
WITH
  dementia_cases AS (
    SELECT
      d.patid,
      d.eventdate AS dementia_index_date,
      p.yob_date,
      p.latest_2,
      p.earliest_4,
      d.subtype AS dementia_subtype,
      d.term AS dementia_term,
      d.icd10 AS dementia_icd10,
      d.medcodeid AS dementia_medcodeid,
      CASE
        WHEN LOWER(TRIM(d.subtype)) = 'alcohol'
        OR COALESCE(m.contains_alcohol, 0) = 1 THEN 1
        ELSE 0
      END AS alcohol_dementia_flag
    FROM
      dementia_index AS d
      INNER JOIN preproc_patient_candidates AS p ON p.patid = d.patid
      LEFT JOIN dementia_index_mixed AS m ON m.patid = d.patid
      AND m.eventdate = d.eventdate
  ),
  eligible_alcohol_events AS (
    SELECT
      e.patid,
      d.dementia_index_date,
      e.eventdate AS alcohol_event_date,
      CASE
        WHEN COALESCE(e.alc_category_status, '') <> 'ACCEPT' THEN NULL
        WHEN e.alc_category = 'non-drinker' THEN 0
        WHEN e.alc_category = 'light-drinker' THEN 1
        WHEN e.alc_category = 'heavy-drinker' THEN 2
        WHEN e.alc_category = 'aud' THEN 3
        ELSE NULL
      END AS alc_level,
      CASE
        WHEN COALESCE(e.alc_category_2_status, '') <> 'ACCEPT' THEN NULL
        WHEN e.alc_category_2 = 'non-drinker' THEN 0
        WHEN e.alc_category_2 = 'trivial-drinker' THEN 1
        WHEN e.alc_category_2 = 'light-moderate' THEN 2
        WHEN e.alc_category_2 = 'heavy-drinker' THEN 3
        WHEN e.alc_category_2 = 'aud' THEN 4
        ELSE NULL
      END AS alc_level_2
    FROM
      dementia_cases AS d
      INNER JOIN preproc_alcohol_events AS e ON e.patid = d.patid
      AND e.eventdate <= d.dementia_index_date
    WHERE
      (
        e.alc_category_status = 'ACCEPT'
        AND e.alc_category IN ('non-drinker', 'light-drinker', 'heavy-drinker', 'aud')
      )
      OR (
        e.alc_category_2_status = 'ACCEPT'
        AND e.alc_category_2 IN ('non-drinker', 'trivial-drinker', 'light-moderate', 'heavy-drinker', 'aud')
      )
  ),
  alcohol_summary AS (
    SELECT
      patid,
      MAX(alc_level) AS max_alc_level,
      MAX(
        CASE
          WHEN alcohol_event_date < DATE_SUB(dementia_index_date, INTERVAL 1 YEAR) THEN alc_level
        END
      ) AS earlier_max_alc_level,
      MAX(
        CASE
          WHEN alcohol_event_date >= DATE_SUB(dementia_index_date, INTERVAL 1 YEAR) THEN alc_level
        END
      ) AS final_year_max_alc_level,
      MAX(alc_level_2) AS max_alc_level_2,
      MAX(
        CASE
          WHEN alcohol_event_date < DATE_SUB(dementia_index_date, INTERVAL 1 YEAR) THEN alc_level_2
        END
      ) AS earlier_max_alc_level_2,
      MAX(
        CASE
          WHEN alcohol_event_date >= DATE_SUB(dementia_index_date, INTERVAL 1 YEAR) THEN alc_level_2
        END
      ) AS final_year_max_alc_level_2,
      MAX(
        CASE
          WHEN alc_level = 3
          OR alc_level_2 = 4 THEN 1
          ELSE 0
        END
      ) AS prior_aud_flag
    FROM
      eligible_alcohol_events
    GROUP BY
      patid
  )
SELECT
  d.patid,
  d.dementia_index_date,
  d.yob_date,
  d.latest_2,
  d.earliest_4,
  d.dementia_subtype,
  d.dementia_term,
  d.dementia_icd10,
  d.dementia_medcodeid,
  d.alcohol_dementia_flag,
  CASE a.max_alc_level
    WHEN 0 THEN 'non-drinker'
    WHEN 1 THEN 'light-drinker'
    WHEN 2 THEN 'heavy-drinker'
    WHEN 3 THEN 'aud'
  END AS highest_alc_category,
  CASE a.earlier_max_alc_level
    WHEN 0 THEN 'non-drinker'
    WHEN 1 THEN 'light-drinker'
    WHEN 2 THEN 'heavy-drinker'
    WHEN 3 THEN 'aud'
  END AS earlier_highest_alc_category,
  CASE a.final_year_max_alc_level
    WHEN 0 THEN 'non-drinker'
    WHEN 1 THEN 'light-drinker'
    WHEN 2 THEN 'heavy-drinker'
    WHEN 3 THEN 'aud'
  END AS final_year_highest_alc_category,
  CASE
    WHEN a.final_year_max_alc_level > a.earlier_max_alc_level THEN 1
    ELSE 0
  END AS alc_category_reverse_causation_flag,
  CASE a.max_alc_level_2
    WHEN 0 THEN 'non-drinker'
    WHEN 1 THEN 'trivial-drinker'
    WHEN 2 THEN 'light-moderate'
    WHEN 3 THEN 'heavy-drinker'
    WHEN 4 THEN 'aud'
  END AS highest_alc_category_2,
  CASE a.earlier_max_alc_level_2
    WHEN 0 THEN 'non-drinker'
    WHEN 1 THEN 'trivial-drinker'
    WHEN 2 THEN 'light-moderate'
    WHEN 3 THEN 'heavy-drinker'
    WHEN 4 THEN 'aud'
  END AS earlier_highest_alc_category_2,
  CASE a.final_year_max_alc_level_2
    WHEN 0 THEN 'non-drinker'
    WHEN 1 THEN 'trivial-drinker'
    WHEN 2 THEN 'light-moderate'
    WHEN 3 THEN 'heavy-drinker'
    WHEN 4 THEN 'aud'
  END AS final_year_highest_alc_category_2,
  CASE
    WHEN a.final_year_max_alc_level_2 > a.earlier_max_alc_level_2 THEN 1
    ELSE 0
  END AS alc_category_2_reverse_causation_flag,
  CASE
    WHEN a.patid IS NOT NULL THEN 1
    ELSE 0
  END AS prior_alcohol_event_flag,
  COALESCE(a.prior_aud_flag, 0) AS prior_aud_flag,
  CASE
    WHEN d.alcohol_dementia_flag = 1
    AND COALESCE(a.prior_aud_flag, 0) = 0 THEN 1
    ELSE 0
  END AS alcohol_dementia_without_prior_aud_flag
FROM
  dementia_cases AS d
  LEFT JOIN alcohol_summary AS a ON a.patid = d.patid;

ALTER TABLE preproc_patient_alcohol_dementia
ADD PRIMARY KEY (patid),
ADD INDEX idx_patient_alcohol_dementia_date (dementia_index_date),
ADD INDEX idx_patient_alcohol_dementia_reverse (alc_category_reverse_causation_flag, alc_category_2_reverse_causation_flag),
ADD INDEX idx_patient_alcohol_dementia_no_aud (alcohol_dementia_without_prior_aud_flag);

/* -------------------------------------------------------------------------
QC: one-row patient counts
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS qc_patient_alcohol_dementia_counts;

CREATE TABLE qc_patient_alcohol_dementia_counts ENGINE = InnoDB AS
SELECT
  COUNT(*) AS n_dementia_patients,
  SUM(prior_alcohol_event_flag) AS n_with_prior_alcohol,
  SUM(alc_category_reverse_causation_flag) AS n_reverse_alc_category,
  SUM(alc_category_2_reverse_causation_flag) AS n_reverse_alc_category_2,
  SUM(alcohol_dementia_flag) AS n_alcohol_dementia,
  SUM(alcohol_dementia_without_prior_aud_flag) AS n_alcohol_dementia_without_prior_aud
FROM
  preproc_patient_alcohol_dementia;
