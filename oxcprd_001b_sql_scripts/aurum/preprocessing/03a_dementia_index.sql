-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
-- 
-- Select one dementia index event per eligible patient
--
-- Algorithm:
--   1. Events before age 18 were removed in 02_dementia.sql.
--   2. MCI events were removed in 02_dementia.sql.
--   3. Find the first event date before applying eligibility criteria.
--   4. If the event on the first date is ineligible, exclude the
--      patient completely. HES wins a same-day HES/CPRD tie.
--   5. CPRD and HES events are eligible from latest_2 through earliest_4.
--   6. If the first date is eligible, it is the dementia index date.
--   7. A specified subtype is preferred to Unspecified.
--  8. At least two distinct specified subtypes on the index date is Mixed unless 
--  one of the subtypes is alcohol then the subtype is alcohol
USE aurum_oxcprd_001b;

/* -------------------------------------------------------------------------
1. Find the first event date before applying eligibility criteria
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS tmp_dementia_first_dates;

CREATE TABLE tmp_dementia_first_dates (patid BIGINT UNSIGNED NOT NULL, eventdate DATE NOT NULL, PRIMARY KEY (patid)) ENGINE = InnoDB;

INSERT INTO
  tmp_dementia_first_dates (patid, eventdate)
SELECT
  patid,
  MIN(eventdate)
FROM
  preproc_dementia_events
GROUP BY
  patid;

/* -------------------------------------------------------------------------
2. Assess the first date and retain its eligible records
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS tmp_dementia_index_day;

CREATE TABLE tmp_dementia_index_day (
  patid BIGINT UNSIGNED NOT NULL,
  eventdate DATE NOT NULL,
  medcodeid BIGINT UNSIGNED NULL,
  icd10 VARCHAR(9) NULL,
  term TEXT NULL,
  subtype VARCHAR(255) NOT NULL,
  specificity TINYINT UNSIGNED NOT NULL,
  selection_rank BIGINT UNSIGNED NOT NULL,
  INDEX idx_tmp_dementia_index_day (patid, eventdate)
) ENGINE = InnoDB;

INSERT INTO
  tmp_dementia_index_day (patid, eventdate, medcodeid, icd10, term, subtype, specificity, selection_rank)
WITH
  first_date_events AS (
    SELECT
      e.source_id,
      e.patid,
      e.eventdate,
      e.medcodeid,
      e.icd10,
      CASE
        WHEN e.source_id = 1 THEN c.term
        WHEN e.source_id = 2 THEN 'dementia_drug'
        ELSE h.`description`
      END AS term,
      CASE
        WHEN e.source_id = 1 THEN c.subtype
        WHEN e.source_id = 2 THEN 'unspecified'
        ELSE h.subtype
      END AS subtype,
      e.specificity,
      s.source_priority,
      -- eligiblity (0 or 1) of earliest dementia event per patid 
      CASE
        WHEN s.source_dataset IN ('cprd', 'hes')
        AND e.eventdate >= p.latest_2
        -- remember that we may need to remove patients that have dementia incidence and death same day for fitting models?
        AND e.eventdate <= p.earliest_4 THEN 1
        ELSE 0
      END AS index_date_record_eligible
    FROM
      tmp_dementia_first_dates AS d
      INNER JOIN preproc_dementia_events AS e ON e.patid = d.patid
      AND e.eventdate = d.eventdate
      INNER JOIN dementia_event_sources AS s ON s.source_id = e.source_id
      INNER JOIN preproc_patient_candidates AS p ON p.patid = e.patid
      LEFT JOIN v0_dementia_codes_AURUM AS c ON e.source_id = 1
      AND c.medcodeid = e.medcodeid
      LEFT JOIN dementia_codes_icd10 AS h ON s.source_dataset = 'hes'
      AND h.icd10 = e.icd10
  ),
  -- is patid eligible? 
  first_date_decisions AS (
    SELECT
      e.*,
      FIRST_VALUE(e.index_date_record_eligible) OVER (
        PARTITION BY
          e.patid
        ORDER BY
          e.source_priority,
          e.source_id
      ) AS patient_eligible_from_first_event
    FROM
      first_date_events AS e
  ),
  -- exclude patients whose first record was ineligible 
  -- remaining records are ranked and first is chosen.
  eligible_index_day AS (
    SELECT
      e.patid,
      e.eventdate,
      e.medcodeid,
      e.icd10,
      e.term,
      e.subtype,
      e.specificity,
      ROW_NUMBER() OVER (
        PARTITION BY
          e.patid
        ORDER BY
          e.specificity DESC,
          e.source_priority,
          e.source_id,
          e.icd10 IS NULL,
          e.icd10,
          e.medcodeid IS NULL,
          e.medcodeid
      ) AS selection_rank
    FROM
      first_date_decisions AS e
    WHERE
      e.patient_eligible_from_first_event = 1
      AND e.index_date_record_eligible = 1
  )
SELECT
  patid,
  eventdate,
  medcodeid,
  icd10,
  term,
  subtype,
  specificity,
  selection_rank
FROM
  eligible_index_day;

/* -------------------------------------------------------------------------
3. Identify Mixed dementia indices

Mixed requires at least two distinct normalised specified subtypes on the
same index date. Duplicate records from one subtype do not create Mixed.
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS dementia_index_mixed;

CREATE TABLE dementia_index_mixed (
  patid BIGINT UNSIGNED NOT NULL,
  eventdate DATE NOT NULL,
  n_distinct_specified SMALLINT UNSIGNED NOT NULL,
  mixed_subtypes TEXT NOT NULL,
  mixed_term TEXT NULL,
  contains_alcohol TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (patid, eventdate),
  INDEX idx_dementia_index_mixed_alcohol (contains_alcohol)
) ENGINE = InnoDB;

INSERT INTO
  dementia_index_mixed (
    patid,
    eventdate,
    n_distinct_specified,
    mixed_subtypes,
    mixed_term,
    contains_alcohol
  )
SELECT
  patid,
  eventdate,
  COUNT(DISTINCT LOWER(TRIM(subtype))) AS n_distinct_specified,
  GROUP_CONCAT(
    DISTINCT LOWER(TRIM(subtype))
    ORDER BY
      LOWER(TRIM(subtype)) SEPARATOR '/'
  ) AS mixed_subtypes,
  GROUP_CONCAT(
    DISTINCT term
    ORDER BY
      term SEPARATOR '/'
  ) AS mixed_term,
  MAX(
    CASE
      WHEN LOWER(TRIM(subtype)) = 'alcohol' THEN 1
      ELSE 0
    END
  ) AS contains_alcohol
FROM
  tmp_dementia_index_day
WHERE
  specificity = 2
GROUP BY
  patid,
  eventdate
HAVING
  COUNT(DISTINCT LOWER(TRIM(subtype))) >= 2;

/* -------------------------------------------------------------------------
4. Create one dementia index event per patient
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS dementia_index;

CREATE TABLE dementia_index (
  patid BIGINT UNSIGNED NOT NULL,
  eventdate DATE NOT NULL,
  subtype VARCHAR(255) NOT NULL,
  term TEXT NULL,
  icd10 VARCHAR(9) NULL,
  medcodeid BIGINT UNSIGNED NULL,
  PRIMARY KEY (patid),
  INDEX idx_dementia_index_eventdate (eventdate),
  INDEX idx_dementia_index_subtype (subtype)
) ENGINE = InnoDB;

INSERT INTO
  dementia_index (patid, eventdate, subtype, term, icd10, medcodeid)
SELECT
  e.patid,
  e.eventdate,
  CASE
    WHEN m.contains_alcohol = 1 THEN 'Alcohol'
    WHEN m.patid IS NOT NULL THEN 'Mixed'
    ELSE e.subtype
  END AS subtype,
  CASE
    WHEN m.patid IS NOT NULL THEN m.mixed_term
    ELSE e.term
  END AS term,
  CASE
    WHEN m.patid IS NOT NULL THEN NULL
    ELSE e.icd10
  END AS icd10,
  CASE
    WHEN m.patid IS NOT NULL THEN NULL
    ELSE e.medcodeid
  END AS medcodeid
FROM
  tmp_dementia_index_day AS e
  LEFT JOIN dementia_index_mixed AS m ON m.patid = e.patid
  AND m.eventdate = e.eventdate
WHERE
  e.selection_rank = 1;

/* -------------------------------------------------------------------------
5. Compact QC outputs
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS qc_dementia_index_counts;

CREATE TABLE qc_dementia_index_counts (
  stage_order SMALLINT UNSIGNED NOT NULL,
  stage VARCHAR(80) NOT NULL,
  n_records BIGINT UNSIGNED NOT NULL,
  n_patients BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (stage_order),
  UNIQUE KEY uq_qc_dementia_index_stage (stage)
) ENGINE = InnoDB;

INSERT INTO
  qc_dementia_index_counts (stage_order, stage, n_records, n_patients)
SELECT
  1,
  'first event dates',
  COUNT(*),
  COUNT(*)
FROM
  tmp_dementia_first_dates
UNION ALL
SELECT
  2,
  'patients excluded by first-date eligibility',
  f.n_patients - i.n_patients,
  f.n_patients - i.n_patients
FROM
  (
    SELECT
      COUNT(*) AS n_patients
    FROM
      tmp_dementia_first_dates
  ) AS f
  CROSS JOIN (
    SELECT
      COUNT(DISTINCT patid) AS n_patients
    FROM
      tmp_dementia_index_day
  ) AS i
UNION ALL
SELECT
  3,
  'eligible patients and index dates',
  COUNT(DISTINCT patid),
  COUNT(DISTINCT patid)
FROM
  tmp_dementia_index_day
UNION ALL
SELECT
  4,
  'eligible index-day records',
  COUNT(*),
  COUNT(DISTINCT patid)
FROM
  tmp_dementia_index_day
UNION ALL
SELECT
  5,
  'mixed dementia indices',
  COUNT(*),
  COUNT(*)
FROM
  dementia_index_mixed
UNION ALL
SELECT
  6,
  'final dementia index',
  COUNT(*),
  COUNT(*)
FROM
  dementia_index;

/* -------------------------------------------------------------------------
6. Cleanup
------------------------------------------------------------------------- */
