-- Smoking status before dementia index for CPRD Aurum.
--
-- Depends on:
--   observation
--   v0_smoking_codes_AURUM
--   v0_smoking_numunitid_aurum
--   preproc_patient_alcohol_dementia, including yob_date
--
-- Performance design:
--   * Start from the dementia cohort and use observation(patid, obsdate).
--   * Carry yob_date in the dementia cohort, avoiding a repeated join to
--     preproc_patient_candidates.
--   * Join the numunit lookup only for ambiguous smoking categories.
--   * Retain only columns required by the next stage.
--   * Resolve prior-smoking history with a window rather than a grouped
--     second pass over all ranked rows.
USE aurum_oxcprd_001b;

/* ----------------------------------------------------------------------
1. Classify eligible smoking observations
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_smoking_classified;

CREATE TABLE tmp_smoking_classified ENGINE = InnoDB AS
SELECT
  p.patid,
  p.dementia_index_date,
  o.obsdate AS eventdate,
  CASE
    WHEN c.smokstatus IN ('non-smoker', 'current-smoker', 'ex-smoker') THEN c.smokstatus
    WHEN u.medcodeid IS NULL THEN NULL
    WHEN u.rule_type = 'ASSUME_CURRENT' THEN 'current-smoker'
    WHEN u.rule_type = 'VALUE_DEPENDENT'
    AND o.value = 0 THEN u.zero_status
    WHEN u.rule_type = 'VALUE_DEPENDENT'
    AND o.value > 0
    AND (
      u.positive_upper_bound_exclusive IS NULL
      OR o.value < u.positive_upper_bound_exclusive
    ) THEN u.positive_status
    ELSE NULL
  END AS smoking_status
FROM
  preproc_patient_alcohol_dementia AS p
  INNER JOIN observation AS o ON o.patid = p.patid
  AND o.obsdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
  AND o.obsdate <= p.dementia_index_date
  INNER JOIN v0_smoking_codes_AURUM AS c ON c.medcodeid = o.medcodeid
  LEFT JOIN v0_smoking_numunitid_aurum AS u ON c.smokstatus IN ('check_status', 'current or ex-smoker')
  AND u.medcodeid = o.medcodeid
  AND u.numunitid = o.numunitid
WHERE
  o.obstypeid <> 4
HAVING
  smoking_status IS NOT NULL;

ALTER TABLE tmp_smoking_classified
ADD INDEX idx_tmp_smoking_patient_date (patid, eventdate);

/* ----------------------------------------------------------------------
2. Resolve same-day conflicts
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_smoking_day;

CREATE TABLE tmp_smoking_day ENGINE = InnoDB AS
SELECT
  e.patid,
  e.dementia_index_date,
  e.eventdate,
  CASE
    WHEN MAX(e.smoking_status = 'ex-smoker') = 1 THEN 'ex-smoker'
    WHEN MAX(e.smoking_status = 'current-smoker') = 1 THEN 'current-smoker'
    WHEN MAX(e.smoking_status = 'non-smoker') = 1 THEN 'non-smoker'
    ELSE NULL
  END AS day_smoking_status
FROM
  tmp_smoking_classified AS e
GROUP BY
  e.patid,
  e.dementia_index_date,
  e.eventdate;

ALTER TABLE tmp_smoking_day
ADD INDEX idx_tmp_smoking_day_patient_date (patid, eventdate);

/* ----------------------------------------------------------------------
3. Rank days and carry prior-smoking history to the latest row
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_smoking_day_ranked;

CREATE TABLE tmp_smoking_day_ranked ENGINE = InnoDB AS
SELECT
  d.patid,
  d.eventdate,
  d.day_smoking_status,
  ROW_NUMBER() OVER (
    PARTITION BY
      d.patid
    ORDER BY
      d.eventdate DESC
  ) AS recency_rank,
  MAX(d.day_smoking_status IN ('current-smoker', 'ex-smoker')) OVER (
    PARTITION BY
      d.patid
    ORDER BY
      d.eventdate ROWS BETWEEN UNBOUNDED PRECEDING
      AND 1 PRECEDING
  ) AS has_prior_smoking
FROM
  tmp_smoking_day AS d;

ALTER TABLE tmp_smoking_day_ranked
ADD INDEX idx_tmp_smoking_ranked_patient (patid, recency_rank);

/* ----------------------------------------------------------------------
4. One smoking-status record per dementia patient
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS preproc_patient_smoking_dementia;

CREATE TABLE preproc_patient_smoking_dementia ENGINE = InnoDB AS
SELECT
  p.patid,
  p.dementia_index_date,
  s.eventdate AS smoking_event_date,
  CASE
    WHEN s.day_smoking_status = 'non-smoker'
    AND COALESCE(s.has_prior_smoking, 0) = 1 THEN 'ex-smoker'
    ELSE s.day_smoking_status
  END AS smoking_status
FROM
  preproc_patient_alcohol_dementia AS p
  LEFT JOIN tmp_smoking_day_ranked AS s ON s.patid = p.patid
  AND s.recency_rank = 1;

ALTER TABLE preproc_patient_smoking_dementia
ADD PRIMARY KEY (patid),
ADD INDEX idx_patient_smoking_dementia_date (dementia_index_date),
ADD INDEX idx_patient_smoking_event_date (smoking_event_date),
ADD INDEX idx_patient_smoking_status (smoking_status);

/* ----------------------------------------------------------------------
5. QC
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS qc_patient_smoking_dementia_counts;

CREATE TABLE qc_patient_smoking_dementia_counts ENGINE = InnoDB AS
SELECT
  COUNT(*) AS n_dementia_patients,
  SUM(smoking_status IS NOT NULL) AS n_with_smoking_status,
  SUM(smoking_status = 'non-smoker') AS n_non_smoker,
  SUM(smoking_status = 'current-smoker') AS n_current_smoker,
  SUM(smoking_status = 'ex-smoker') AS n_ex_smoker
FROM
  preproc_patient_smoking_dementia;
