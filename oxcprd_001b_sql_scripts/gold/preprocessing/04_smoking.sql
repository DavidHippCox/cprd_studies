-- Authored by David Hippisley-Cox
-- project: gold_oxcprd_001b
-- analysis plan version: NA
-- smoking_mariadb_pipeline_v1.sql
-- MariaDB 12.3.2 rewrite of smoking_sqlite_pipeline_v1.sql.
--
-- Main changes:
--   * Uses a session-scoped temporary codelist table.
--   * Replaces intermediate SQLite views with indexed temporary stages.
--   * Does not drop the source codelist table.
--   * Uses the existing pracid columns in Clinical and Additional.
--   * Avoids casts on join columns so source indexes remain usable.
--
-- Required source codelist:
--   smoking_codes_GOLD
--
-- Assumptions:
--   * Source and codelist join columns have compatible data types.
--   * smoking_codes_GOLD contains at most one row per medcode.
--   * preproc_base contains at most one row per patid.
--   * pc_clinical and pc_additional contain compatible pracid columns.
--   * pc_clinical and pc_additional are indexed on (adid, pracid).

/* -------------------------------------------------------------------------
   1. Session-scoped codelist
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_smoking_cprd_codes;
CREATE TEMPORARY TABLE tmp_smoking_cprd_codes (
    medcode BIGINT UNSIGNED NOT NULL,
    description TEXT NULL,
    smokstatus VARCHAR(255) NULL,
    PRIMARY KEY (medcode)
) ENGINE=InnoDB;

INSERT INTO tmp_smoking_cprd_codes (
    medcode,
    description,
    smokstatus
)
SELECT
    medcode,
    description,
    smokstatus
FROM smoking_codes_GOLD
WHERE medcode IS NOT NULL;

/* -------------------------------------------------------------------------
   2. Cohort-restricted Clinical and Additional stages
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_smoking_clinical_events;

CREATE TEMPORARY TABLE tmp_smoking_clinical_events
ENGINE=InnoDB
AS
SELECT
    c.patid,
    c.pracid,
    c.eventdate,
    c.medcode,
    c.enttype,
    c.adid,
    cl.description,
    cl.smokstatus
FROM pc_clinical AS c
INNER JOIN tmp_smoking_cprd_codes AS cl
    ON cl.medcode = c.medcode
INNER JOIN preproc_base AS cb
    ON cb.patid = c.patid;

ALTER TABLE tmp_smoking_clinical_events
    ADD INDEX idx_tmp_smoking_clinical_adid_pracid (adid, pracid);

DROP TEMPORARY TABLE IF EXISTS tmp_smoking_additional;

CREATE TEMPORARY TABLE tmp_smoking_additional
ENGINE=InnoDB
AS
SELECT
    a.pracid,
    a.adid,
    CASE TRIM(CAST(a.data1 AS CHAR))
        WHEN '0' THEN 'not-recorded'
        WHEN '1' THEN 'current-smoker'
        WHEN '2' THEN 'non-smoker'
        WHEN '3' THEN 'ex-smoker'
        ELSE NULL
    END AS add_smokstatus,
    a.enttype
FROM pc_additional AS a
INNER JOIN preproc_base AS cb
    ON cb.patid = a.patid;

ALTER TABLE tmp_smoking_additional
    ADD INDEX idx_tmp_smoking_additional_adid_pracid (adid, pracid);

/* -------------------------------------------------------------------------
   3. Additional enttype 4 records absent from smoking Clinical events
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS smoking_additional_ent4_missing_in_clinical;

CREATE TABLE smoking_additional_ent4_missing_in_clinical
ENGINE=InnoDB
AS
SELECT
    a.pracid,
    a.adid,
    a.add_smokstatus,
    a.enttype
FROM tmp_smoking_additional AS a
LEFT JOIN (
    SELECT DISTINCT
        adid,
        pracid
    FROM tmp_smoking_clinical_events
    WHERE adid IS NOT NULL
) AS ck
    ON ck.adid = a.adid
   AND ck.pracid = a.pracid
WHERE a.enttype = 4
  AND ck.adid IS NULL;

/* -------------------------------------------------------------------------
   4. All smoking events plus the lifetime/time-in-practice flag
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS smoking_log_events;

CREATE TABLE smoking_log_events
ENGINE=InnoDB
AS
SELECT
    e.source_table,
    e.source_dataset,
    e.patid,
    e.eventdate,
    e.medcode,
    e.enttype,
    e.adid,
    e.pracid,
    e.add_smokstatus,
    e.description,
    e.smokstatus,
    cb.yob,
    cb.tod,
    cb.merged_death,
    CASE
        WHEN e.eventdate > cb.yob
         AND (cb.tod IS NULL OR e.eventdate <= cb.tod)
         AND (
                cb.merged_death IS NULL
                OR e.eventdate <= cb.merged_death
             )
            THEN 1
        ELSE 0
    END AS keep_flag
FROM (
    SELECT
        'clinical_add' AS source_table,
        'cprd' AS source_dataset,
        c.patid,
        c.eventdate,
        c.medcode,
        c.enttype,
        c.adid,
        c.pracid,
        a.add_smokstatus,
        c.description,
        c.smokstatus
    FROM tmp_smoking_clinical_events AS c
    LEFT JOIN tmp_smoking_additional AS a
        ON a.adid = c.adid
       AND a.pracid = c.pracid

    UNION ALL

    SELECT
        'test' AS source_table,
        'cprd' AS source_dataset,
        t.patid,
        t.eventdate,
        t.medcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        CAST(NULL AS UNSIGNED) AS pracid,
        CAST(NULL AS CHAR(14)) AS add_smokstatus,
        cl.description,
        cl.smokstatus
    FROM pc_test AS t
    INNER JOIN tmp_smoking_cprd_codes AS cl
        ON cl.medcode = t.medcode

    UNION ALL

    SELECT
        'referral' AS source_table,
        'cprd' AS source_dataset,
        r.patid,
        r.eventdate,
        r.medcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        CAST(NULL AS UNSIGNED) AS pracid,
        CAST(NULL AS CHAR(14)) AS add_smokstatus,
        cl.description,
        cl.smokstatus
    FROM pc_referral AS r
    INNER JOIN tmp_smoking_cprd_codes AS cl
        ON cl.medcode = r.medcode
) AS e
INNER JOIN preproc_base AS cb
    ON cb.patid = e.patid
WHERE e.eventdate IS NOT NULL;

ALTER TABLE smoking_log_events
    ADD INDEX idx_smoking_log_patid_eventdate (patid, eventdate),
    ADD INDEX idx_smoking_log_source (source_dataset, source_table);

/* -------------------------------------------------------------------------
   5. Retained smoking events
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS preproc_smoking_events;

CREATE TABLE preproc_smoking_events
ENGINE=InnoDB
AS
SELECT
    source_table,
    source_dataset,
    patid,
    eventdate,
    medcode,
    enttype,
    adid,
    pracid,
    add_smokstatus,
    description,
    smokstatus
FROM smoking_log_events
WHERE keep_flag = 1;

ALTER TABLE preproc_smoking_events
    ADD INDEX idx_smoking_events_patid_eventdate (patid, eventdate),
    ADD INDEX idx_smoking_events_source (
        source_dataset,
        source_table,
        patid
    ),
    ADD INDEX idx_smoking_events_medcode (medcode);

/* -------------------------------------------------------------------------
   6. QC summaries
   ------------------------------------------------------------------------- */

DROP VIEW IF EXISTS v_qc_smoking_event_counts;

CREATE VIEW v_qc_smoking_event_counts AS
SELECT
    source_dataset,
    source_table,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT patid) AS n_patients
FROM preproc_smoking_events
GROUP BY
    source_dataset,
    source_table;

DROP VIEW IF EXISTS v_qc_smoking_additional_ent4_missing_count;

CREATE VIEW v_qc_smoking_additional_ent4_missing_count AS
SELECT
    COUNT(*) AS n_rows
FROM smoking_additional_ent4_missing_in_clinical;

/* -------------------------------------------------------------------------
   7. Explicit cleanup; these would also disappear at session end
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_smoking_additional;
DROP TEMPORARY TABLE IF EXISTS tmp_smoking_clinical_events;
DROP TEMPORARY TABLE IF EXISTS tmp_smoking_cprd_codes;
