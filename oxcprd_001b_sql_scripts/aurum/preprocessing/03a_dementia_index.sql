-- 03. Select one dementia index event per eligible patient
--
-- Rules:
--   1. Events before age 18 were removed in 02_dementia.sql.
--   2. MCI events remain available for QC but cannot determine eligibility
--      or become the dementia index event.
--   3. The first non-MCI event determines patient eligibility. HES wins a
--      same-day HES/CPRD tie.
--   4. CPRD events are eligible from latest_2 through earliest_4.
--   5. HES events are eligible from 1998-01-02 through the earlier of
--      2024-06-24 and merged_death.
--   6. If the first non-MCI event is eligible, its date is the index date.
--   7. Only eligible, non-MCI rows on the index date are resolved.
--   8. A specified subtype is preferred to Unspecified.
--   9. More than one distinct specified subtype on the index date is Mixed.
USE aurum_oxcprd_001b;

/* -------------------------------------------------------------------------
1. Find the first non-MCI event date
------------------------------------------------------------------------- */
DROP TEMPORARY TABLE IF EXISTS tmp_dementia_first_dates;

CREATE TEMPORARY TABLE tmp_dementia_first_dates (patid BIGINT UNSIGNED NOT NULL, eventdate DATE NOT NULL, PRIMARY KEY (patid)) ENGINE = InnoDB;

INSERT INTO
  tmp_dementia_first_dates (patid, eventdate)
SELECT
  patid,
  MIN(eventdate)
FROM
  preproc_dementia_events
WHERE
  specificity > 0
GROUP BY
  patid;

/* -------------------------------------------------------------------------
2. Apply the same-day source priority and assess eligibility
------------------------------------------------------------------------- */
DROP TEMPORARY TABLE IF EXISTS tmp_dementia_first_events;

CREATE TEMPORARY TABLE tmp_dementia_first_events (
  patid BIGINT UNSIGNED NOT NULL,
  eventdate DATE NOT NULL,
  source_id TINYINT UNSIGNED NOT NULL,
  event_eligible TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (patid)
) ENGINE = InnoDB;

INSERT INTO
  tmp_dementia_first_events (patid, eventdate, source_id, event_eligible)
SELECT
  r.patid,
  r.eventdate,
  r.source_id,
  r.event_eligible
FROM
  (
    SELECT
      e.patid,
      e.eventdate,
      e.source_id,
      CASE
        WHEN s.source_dataset = 'cprd'
        AND e.eventdate >= p.latest_2
        AND e.eventdate <= p.earliest_4 THEN 1
        WHEN s.source_dataset = 'hes'
        AND e.eventdate >= DATE '1998-01-02'
        AND e.eventdate <= LEAST(DATE '2024-06-24', COALESCE(p.merged_death, DATE '2024-06-24')) THEN 1
        ELSE 0
      END AS event_eligible,
      ROW_NUMBER() OVER (
        PARTITION BY
          e.patid
        ORDER BY
          s.source_priority,
          e.source_id
      ) AS event_rank
    FROM
      tmp_dementia_first_dates AS d
      INNER JOIN preproc_dementia_events AS e ON e.patid = d.patid
      AND e.eventdate = d.eventdate
      INNER JOIN dementia_event_sources AS s ON s.source_id = e.source_id
      INNER JOIN preproc_patient_candidates AS p ON p.patid = e.patid
    WHERE
      e.specificity > 0
  ) AS r
WHERE
  r.event_rank = 1;

/* -------------------------------------------------------------------------
3. Resolve eligible, non-MCI rows on the index date
------------------------------------------------------------------------- */
DROP TEMPORARY TABLE IF EXISTS tmp_dementia_index_day;

CREATE TEMPORARY TABLE tmp_dementia_index_day (
  source_id TINYINT UNSIGNED NOT NULL,
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
  tmp_dementia_index_day (
    source_id,
    patid,
    eventdate,
    medcodeid,
    icd10,
    term,
    subtype,
    specificity,
    selection_rank
  )
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
  ROW_NUMBER() OVER (
    PARTITION BY
      e.patid
    ORDER BY
      e.specificity DESC,
      s.source_priority,
      e.source_id,
      e.icd10 IS NULL,
      e.icd10,
      e.medcodeid IS NULL,
      e.medcodeid
  ) AS selection_rank
FROM
  preproc_dementia_events AS e
  INNER JOIN tmp_dementia_first_events AS f ON f.patid = e.patid
  AND f.eventdate = e.eventdate
  AND f.event_eligible = 1
  INNER JOIN dementia_event_sources AS s ON s.source_id = e.source_id
  INNER JOIN preproc_patient_candidates AS p ON p.patid = e.patid
  LEFT JOIN v0_dementia_codes_AURUM AS c ON e.source_id = 1
  AND c.medcodeid = e.medcodeid
  LEFT JOIN dementia_codes_icd10 AS h ON s.source_dataset = 'hes'
  AND h.icd10 = e.icd10
WHERE
  e.specificity > 0
  AND (
    (
      s.source_dataset = 'cprd'
      AND e.eventdate >= p.latest_2
      AND e.eventdate <= p.earliest_4
    )
    OR (
      s.source_dataset = 'hes'
      AND e.eventdate >= DATE '1998-01-02'
      AND e.eventdate <= LEAST(DATE '2024-06-24', COALESCE(p.merged_death, DATE '2024-06-24'))
    )
  );

DROP TEMPORARY TABLE IF EXISTS tmp_dementia_index_day_summary;

CREATE TEMPORARY TABLE tmp_dementia_index_day_summary (
  patid BIGINT UNSIGNED NOT NULL,
  eventdate DATE NOT NULL,
  n_distinct_specified SMALLINT UNSIGNED NOT NULL,
  mixed_term TEXT NULL,
  PRIMARY KEY (patid, eventdate)
) ENGINE = InnoDB;

INSERT INTO
  tmp_dementia_index_day_summary (patid, eventdate, n_distinct_specified, mixed_term)
SELECT
  patid,
  eventdate,
  COUNT(
    DISTINCT CASE
      WHEN specificity = 2 THEN LOWER(TRIM(subtype))
      ELSE NULL
    END
  ) AS n_distinct_specified,
  CASE
    WHEN COUNT(
      DISTINCT CASE
        WHEN specificity = 2 THEN LOWER(TRIM(subtype))
        ELSE NULL
      END
    ) > 1 THEN GROUP_CONCAT(
      DISTINCT CASE
        WHEN specificity = 2 THEN term
        ELSE NULL
      END
      ORDER BY
        term SEPARATOR '/'
    )
    ELSE NULL
  END AS mixed_term
FROM
  tmp_dementia_index_day
GROUP BY
  patid,
  eventdate;

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
    WHEN s.n_distinct_specified > 1 THEN 'Mixed'
    ELSE e.subtype
  END AS subtype,
  CASE
    WHEN s.n_distinct_specified > 1 THEN s.mixed_term
    ELSE e.term
  END AS term,
  CASE
    WHEN s.n_distinct_specified > 1 THEN NULL
    ELSE e.icd10
  END AS icd10,
  CASE
    WHEN s.n_distinct_specified > 1 THEN NULL
    ELSE e.medcodeid
  END AS medcodeid
FROM
  tmp_dementia_index_day AS e
  INNER JOIN tmp_dementia_index_day_summary AS s ON s.patid = e.patid
  AND s.eventdate = e.eventdate
WHERE
  e.selection_rank = 1;

/* -------------------------------------------------------------------------
5. Compact QC outputs
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS qc_dementia_index_mixed_records;

CREATE TABLE qc_dementia_index_mixed_records ENGINE = InnoDB AS
SELECT
  e.source_id,
  e.patid,
  e.eventdate,
  e.medcodeid,
  e.icd10,
  e.term,
  e.subtype
FROM
  tmp_dementia_index_day AS e
  INNER JOIN tmp_dementia_index_day_summary AS s ON s.patid = e.patid
  AND s.eventdate = e.eventdate
WHERE
  s.n_distinct_specified > 1
  AND e.specificity = 2;

-- Remove superseded QC tables so stale outputs cannot be mistaken for current
-- results.
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
  stages.stage_order,
  stages.stage,
  CASE stages.stage_order
    WHEN 1 THEN c.all_records
    WHEN 2 THEN c.mci_records
    WHEN 3 THEN c.non_mci_records
  END AS n_records,
  CASE stages.stage_order
    WHEN 1 THEN c.all_patients
    WHEN 2 THEN c.mci_patients
    WHEN 3 THEN c.non_mci_patients
  END AS n_patients
FROM
  (
    SELECT
      COUNT(*) AS all_records,
      COUNT(DISTINCT patid) AS all_patients,
      COUNT(
        CASE
          WHEN specificity = 0 THEN 1
        END
      ) AS mci_records,
      COUNT(
        DISTINCT CASE
          WHEN specificity = 0 THEN patid
        END
      ) AS mci_patients,
      COUNT(
        CASE
          WHEN specificity > 0 THEN 1
        END
      ) AS non_mci_records,
      COUNT(
        DISTINCT CASE
          WHEN specificity > 0 THEN patid
        END
      ) AS non_mci_patients
    FROM
      preproc_dementia_events
  ) AS c
  CROSS JOIN (
    SELECT
      1 AS stage_order,
      'valid source events' AS stage
    UNION ALL
    SELECT
      2,
      'MCI events retained but not used'
    UNION ALL
    SELECT
      3,
      'non-MCI events considered'
  ) AS stages;

INSERT INTO
  qc_dementia_index_counts (stage_order, stage, n_records, n_patients)
SELECT
  4,
  'first non-MCI events',
  COUNT(*),
  COUNT(*)
FROM
  tmp_dementia_first_events
UNION ALL
SELECT
  5,
  'patients excluded by first-event eligibility',
  COUNT(
    CASE
      WHEN event_eligible = 0 THEN 1
    END
  ),
  COUNT(
    CASE
      WHEN event_eligible = 0 THEN 1
    END
  )
FROM
  tmp_dementia_first_events
UNION ALL
SELECT
  6,
  'eligible patients and index dates',
  COUNT(
    CASE
      WHEN event_eligible = 1 THEN 1
    END
  ),
  COUNT(
    CASE
      WHEN event_eligible = 1 THEN 1
    END
  )
FROM
  tmp_dementia_first_events
UNION ALL
SELECT
  7,
  'eligible non-MCI index-day records',
  COUNT(*),
  COUNT(DISTINCT patid)
FROM
  tmp_dementia_index_day
UNION ALL
SELECT
  8,
  'mixed index-date specified records',
  COUNT(*),
  COUNT(DISTINCT patid)
FROM
  qc_dementia_index_mixed_records
UNION ALL
SELECT
  9,
  'final dementia index',
  COUNT(*),
  COUNT(*)
FROM
  dementia_index;

/* -------------------------------------------------------------------------
6. Cleanup
------------------------------------------------------------------------- */
DROP TEMPORARY TABLE IF EXISTS tmp_dementia_index_day_summary;

DROP TEMPORARY TABLE IF EXISTS tmp_dementia_index_day;

DROP TEMPORARY TABLE IF EXISTS tmp_dementia_first_events;

DROP TEMPORARY TABLE IF EXISTS tmp_dementia_first_dates;
