-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
-- analysis plan v2: prior history restricts sensitivity analyses only.
-- this was used to create table 1 v2
-- 
-- Defintions:
-- We define an outcome that occures on the cohort entry date: 
-- dementia_index_date to be 'pre_dem'. 
--
-- Events before latest 2 i.e (earliest of {study start, 
-- date registration start date} also contribute to 'pre_dem' identification.
-- so
--        pre_dem  : eventdate <= dementia_index_date (includes index day)
--        post_dem : eventdate > dementia_index_date
-- 
-- Primary analyses retain patients with prior/index-day events.
-- sensitivity_eligible=1 means no prior/index-day event for that outcome.
-- event/time_days describe the first post-index event for all patients.
-- A prior event alone is not a post-index outcome.
-- Index-day censoring has event=0 and time_days=0.
USE aurum_oxcprd_001b;

/* ----------------------------------------------------------------------
1. Unify the outcome code mappings
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_outcome_code_map;

CREATE TABLE tmp_outcome_code_map (
  feature VARCHAR(64) NOT NULL,
  outcome_prefix VARCHAR(64) NOT NULL,
  medcodeid BIGINT UNSIGNED NULL,
  prodcodeid BIGINT UNSIGNED NULL,
  term TEXT NULL,
  INDEX idx_outcome_map_medcode (medcodeid),
  INDEX idx_outcome_map_prodcode (prodcodeid)
) ENGINE = InnoDB;

INSERT INTO
  tmp_outcome_code_map (feature, outcome_prefix, medcodeid, prodcodeid, term)
SELECT
  'care_home',
  'care_home',
  c.medcodeid,
  NULL,
  c.term
FROM
  v0_care_home_codes_AURUM AS c
WHERE
  c.medcodeid IS NOT NULL
UNION ALL
SELECT
  'neuropsychiatric',
  c.nsp_subtype,
  c.medcodeid,
  NULL,
  c.term
FROM
  v0_neuropsychiatric_codes_AURUM AS c
WHERE
  c.medcodeid IS NOT NULL
  AND c.nsp_subtype IN ('psychosis', 'delirium', 'affective', 'challenging');

INSERT INTO
  tmp_outcome_code_map (feature, outcome_prefix, medcodeid, prodcodeid, term)
SELECT
  'medication',
  c.drugtypes,
  NULL,
  c.prodcodeid,
  c.termfromemis
FROM
  v0_medication_codes_AURUM AS c
WHERE
  c.prodcodeid IS NOT NULL
  AND c.drugtypes IN (
    'antipsychotics',
    'antidepressants',
    'antipsychotics_antidepressants',
    'anxiety_and_hypnotics'
  );

/* ----------------------------------------------------------------------
2. Extract adult outcome records for analysis_pop
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_outcome_events;

CREATE TABLE tmp_outcome_events ENGINE = InnoDB AS
SELECT
  m.outcome_prefix,
  p.patid,
  o.obsdate AS eventdate,
  CASE
    WHEN o.obsdate <= p.dementia_index_date THEN 'pre_dem'
    WHEN o.obsdate > p.dementia_index_date THEN 'post_dem'
  END AS window_bin,
  o.medcodeid,
  CAST(NULL AS UNSIGNED) AS prodcodeid,
  m.term
FROM
  analysis_pop AS p
  INNER JOIN observation AS o ON o.patid = p.patid
  AND o.obsdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
  INNER JOIN tmp_outcome_code_map AS m ON m.medcodeid = o.medcodeid
UNION ALL
SELECT
  m.outcome_prefix,
  p.patid,
  d.issuedate AS eventdate,
  CASE
    WHEN d.issuedate <= p.dementia_index_date THEN 'pre_dem'
    WHEN d.issuedate > p.dementia_index_date THEN 'post_dem'
  END AS window_bin,
  CAST(NULL AS UNSIGNED) AS medcodeid,
  d.prodcodeid,
  m.term
FROM
  analysis_pop AS p
  INNER JOIN drugissue AS d ON d.patid = p.patid
  AND d.issuedate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
  INNER JOIN tmp_outcome_code_map AS m ON m.prodcodeid = d.prodcodeid;

ALTER TABLE tmp_outcome_events
ADD INDEX idx_tmp_outcome_prefix_patient_window_date (outcome_prefix, patid, window_bin, eventdate);

/* ----------------------------------------------------------------------
3. Aggregate the first date in each period
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_outcome_first_dates;

CREATE TABLE tmp_outcome_first_dates ENGINE = InnoDB AS
SELECT
  e.outcome_prefix,
  e.patid,
  MIN(
    CASE
      WHEN e.window_bin = 'pre_dem' THEN e.eventdate
    END
  ) AS first_pre_dem_eventdate,
  MIN(
    CASE
      WHEN e.window_bin = 'post_dem' THEN e.eventdate
    END
  ) AS first_post_dem_eventdate
FROM
  tmp_outcome_events AS e
GROUP BY
  e.outcome_prefix,
  e.patid;

ALTER TABLE tmp_outcome_first_dates
ADD PRIMARY KEY (outcome_prefix, patid);

/* ----------------------------------------------------------------------
4. Select matching terms, ranking only ties on the first dates
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_outcome_selected;

CREATE TABLE tmp_outcome_selected ENGINE = InnoDB AS
SELECT
  r.outcome_prefix,
  r.patid,
  r.window_bin,
  r.eventdate,
  r.term
FROM
  (
    SELECT
      e.outcome_prefix,
      e.patid,
      e.window_bin,
      e.eventdate,
      e.term,
      ROW_NUMBER() OVER (
        PARTITION BY
          e.outcome_prefix,
          e.patid,
          e.window_bin
        ORDER BY
          COALESCE(e.medcodeid, 0),
          COALESCE(e.prodcodeid, 0),
          e.term
      ) AS event_rank
    FROM
      tmp_outcome_first_dates AS f
      INNER JOIN tmp_outcome_events AS e ON e.outcome_prefix = f.outcome_prefix
      AND e.patid = f.patid
      AND e.window_bin = 'pre_dem'
      AND e.eventdate = f.first_pre_dem_eventdate
    UNION ALL
    SELECT
      e.outcome_prefix,
      e.patid,
      e.window_bin,
      e.eventdate,
      e.term,
      ROW_NUMBER() OVER (
        PARTITION BY
          e.outcome_prefix,
          e.patid,
          e.window_bin
        ORDER BY
          COALESCE(e.medcodeid, 0),
          COALESCE(e.prodcodeid, 0),
          e.term
      ) AS event_rank
    FROM
      tmp_outcome_first_dates AS f
      INNER JOIN tmp_outcome_events AS e ON e.outcome_prefix = f.outcome_prefix
      AND e.patid = f.patid
      AND e.window_bin = 'post_dem'
      AND e.eventdate = f.first_post_dem_eventdate
  ) AS r
WHERE
  r.event_rank = 1;

ALTER TABLE tmp_outcome_selected
ADD PRIMARY KEY (outcome_prefix, patid, window_bin);

/* ----------------------------------------------------------------------
5. Inspectable intermediate table: every patient and configured outcome
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS preproc_outcome_features_long;

CREATE TABLE preproc_outcome_features_long ENGINE = InnoDB AS
WITH
  outcome_prefixes AS (
    SELECT
      'care_home' AS feature,
      'care_home' AS outcome_prefix
    UNION ALL
    SELECT
      'medication',
      'antipsychotics'
    UNION ALL
    SELECT
      'medication',
      'antidepressants'
    UNION ALL
    SELECT
      'medication',
      'antipsychotics_antidepressants'
    UNION ALL
    SELECT
      'medication',
      'anxiety_and_hypnotics'
    UNION ALL
    SELECT
      'neuropsychiatric',
      'psychosis'
    UNION ALL
    SELECT
      'neuropsychiatric',
      'delirium'
    UNION ALL
    SELECT
      'neuropsychiatric',
      'affective'
    UNION ALL
    SELECT
      'neuropsychiatric',
      'challenging'
  ),
  outcome_rows AS (
    SELECT
      p.patid,
      p.dementia_index_date,
      p.latest_2,
      p.earliest_4,
      x.feature,
      x.outcome_prefix,
      pre.eventdate AS first_pre_dem_eventdate,
      pre.term AS first_pre_dem_term,
      post.eventdate AS first_post_dem_eventdate,
      post.term AS first_post_dem_term,
      -- Prior history restricts sensitivity analyses only.
      -- Zero-day follow-up does not alter this history flag.
      (pre.patid IS NULL) AS sensitivity_eligible
    FROM
      analysis_pop AS p
      CROSS JOIN outcome_prefixes AS x
      LEFT JOIN tmp_outcome_selected AS pre ON pre.patid = p.patid
      AND pre.outcome_prefix = x.outcome_prefix
      AND pre.window_bin = 'pre_dem'
      LEFT JOIN tmp_outcome_selected AS post ON post.patid = p.patid
      AND post.outcome_prefix = x.outcome_prefix
      AND post.window_bin = 'post_dem'
  )
SELECT
  r.patid,
  r.dementia_index_date,
  r.latest_2,
  r.earliest_4,
  r.feature,
  r.outcome_prefix,
  r.first_pre_dem_eventdate,
  r.first_pre_dem_term,
  r.first_post_dem_eventdate,
  r.first_post_dem_term,
  r.sensitivity_eligible,
  -- Primary outcomes include patients with and without prior events.
  COALESCE(r.first_post_dem_eventdate <= r.earliest_4, 0) AS event,
  DATEDIFF(
    LEAST(COALESCE(r.first_post_dem_eventdate, r.earliest_4), r.earliest_4),
    r.dementia_index_date
  ) AS time_days
FROM
  outcome_rows AS r;

ALTER TABLE preproc_outcome_features_long
ADD PRIMARY KEY (outcome_prefix, patid),
ADD INDEX idx_outcome_features_patient (patid);

/* ----------------------------------------------------------------------
6. QC: counts from the retained intermediate table
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS qc_post_dementia_outcome_counts;

CREATE TABLE qc_post_dementia_outcome_counts ENGINE = InnoDB AS
SELECT
  feature,
  outcome_prefix,
  -- Total patients
  COUNT(*) AS n_analysis_patients,
  -- Pre- and post-dementia event counts
  SUM(first_pre_dem_eventdate IS NOT NULL) AS n_with_pre_dem_event,
  SUM(first_post_dem_eventdate IS NOT NULL) AS n_with_post_dem_event,
  -- History before the start of the pre-dementia window
  SUM(first_pre_dem_eventdate < latest_2) AS n_with_history_before_latest_2,
  SUM(sensitivity_eligible = 1) AS n_sensitivity_eligible,
  SUM(sensitivity_eligible = 0) AS n_sensitivity_excluded_prior,
  SUM(event = 1) AS n_post_dem_events,
  SUM(event = 0) AS n_censored,
  SUM(
    sensitivity_eligible = 1
    AND event = 1
  ) AS n_sensitivity_events,
  SUM(
    sensitivity_eligible = 1
    AND event = 0
  ) AS n_sensitivity_censored,
  AVG (time_days) AS mean_time_days,
  MIN(time_days) AS min_time_days,
  MAX(time_days) AS max_time_days
FROM
  preproc_outcome_features_long
GROUP BY
  feature,
  outcome_prefix;

/* ----------------------------------------------------------------------
9. Cleanup: retain preproc_outcome_features_long and the feature/QC tables
------------------------------------------------------------------------ */
