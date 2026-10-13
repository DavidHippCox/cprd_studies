-- confounders_mariadb_pipeline_v1.sql
-- MariaDB 12.3.2 rewrite of the depression/anxiety, SMI, and TBI
-- confounder R pipelines.
--
-- These are confounders, not post-dementia outcomes. The patient-level
-- classification uses only the earliest retained event for each confounder:
--   confounder    : eventdate < dementia_eventdate - 1095 days
--   exclusion     : eventdate >= dementia_eventdate - 1095 days
--                   and eventdate <= dementia_eventdate
--   post_dementia : eventdate > dementia_eventdate
--
-- Main outputs:
--   confounder_log_events
--   preproc_confounder_events
--   preproc_depression_anxiety_events
--   preproc_smi_events
--   preproc_tbi_events
--   confounder_first_events
--   preproc_confounder_features_long
--   feat_depression_anxiety
--   feat_smi
--   feat_tbi
--
-- Required codelist tables:
--   depression_anxiety_codes_GOLD
--   smi_codes_GOLD
--   tbi_codes_GOLD
--
-- Required cohort columns:
--   preproc_base (
--       patid, yob, tod, merged_death, dementia_eventdate
--   )
--
-- Recommended source indexes, created once outside this pipeline:
--   pc_clinical (medcode, eventdate, patid)
--   pc_test (medcode, eventdate, patid)
--   pc_referral (medcode, eventdate, patid)
--   preproc_base (patid)
--
-- No stored procedure is required. All three fixed confounders use the same
-- set-based transformations and can share a normalized event pipeline.

/* -------------------------------------------------------------------------
   1. Session-scoped unified codelist and feature list
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_confounder_codes;
CREATE TEMPORARY TABLE tmp_confounder_codes (
    confounder_name VARCHAR(64) NOT NULL,
    medcode BIGINT UNSIGNED NOT NULL,
    description TEXT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_confounder_codes (
    confounder_name,
    medcode,
    description
)
SELECT
    'depression_anxiety',
    medcode,
    description
FROM depression_anxiety_codes_GOLD
WHERE medcode IS NOT NULL;

INSERT INTO tmp_confounder_codes (
    confounder_name,
    medcode,
    description
)
SELECT
    'smi',
    medcode,
    description
FROM smi_codes_GOLD
WHERE medcode IS NOT NULL;

INSERT INTO tmp_confounder_codes (
    confounder_name,
    medcode,
    description
)
SELECT
    'tbi',
    medcode,
    description
FROM tbi_codes_GOLD
WHERE medcode IS NOT NULL;

ALTER TABLE tmp_confounder_codes
    ADD INDEX idx_tmp_confounder_medcode (medcode, confounder_name);

DROP TEMPORARY TABLE IF EXISTS tmp_confounder_names;
CREATE TEMPORARY TABLE tmp_confounder_names (
    confounder_name VARCHAR(64) NOT NULL,
    PRIMARY KEY (confounder_name)
) ENGINE=InnoDB;

INSERT INTO tmp_confounder_names (confounder_name)
VALUES
    ('depression_anxiety'),
    ('smi'),
    ('tbi');

/* -------------------------------------------------------------------------
   2. Extract, describe, and apply lifetime/time-in-practice filtering
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS confounder_log_events;

CREATE TABLE confounder_log_events
ENGINE=InnoDB
AS
SELECT
    e.confounder_name,
    e.source_table,
    e.source_dataset,
    e.source_rank,
    e.patid,
    e.eventdate,
    e.medcode,
    e.enttype,
    e.adid,
    e.description,
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
        cd.confounder_name,
        'clinical' AS source_table,
        'cprd' AS source_dataset,
        1 AS source_rank,
        c.patid,
        c.eventdate,
        c.medcode,
        c.enttype,
        c.adid,
        cd.description
    FROM tmp_confounder_codes AS cd
    INNER JOIN pc_clinical AS c
        ON c.medcode = cd.medcode

    UNION ALL

    SELECT
        cd.confounder_name,
        'referral' AS source_table,
        'cprd' AS source_dataset,
        2 AS source_rank,
        r.patid,
        r.eventdate,
        r.medcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        cd.description
    FROM tmp_confounder_codes AS cd
    INNER JOIN pc_referral AS r
        ON r.medcode = cd.medcode

    UNION ALL

    SELECT
        cd.confounder_name,
        'test' AS source_table,
        'cprd' AS source_dataset,
        3 AS source_rank,
        t.patid,
        t.eventdate,
        t.medcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        cd.description
    FROM tmp_confounder_codes AS cd
    INNER JOIN pc_test AS t
        ON t.medcode = cd.medcode
) AS e
INNER JOIN preproc_base AS cb
    ON cb.patid = e.patid
WHERE e.eventdate IS NOT NULL;

DROP TABLE IF EXISTS preproc_confounder_events;

CREATE TABLE preproc_confounder_events
ENGINE=InnoDB
AS
SELECT
    confounder_name,
    source_table,
    source_dataset,
    source_rank,
    patid,
    eventdate,
    medcode,
    enttype,
    adid,
    description
FROM confounder_log_events
WHERE keep_flag = 1;

ALTER TABLE preproc_confounder_events
    ADD INDEX idx_confounder_name_patid_date (
        confounder_name,
        patid,
        eventdate
    ),
    ADD INDEX idx_confounder_source (
        confounder_name,
        source_table,
        patid
    ),
    ADD INDEX idx_confounder_medcode (medcode);

/* -------------------------------------------------------------------------
   3. R-compatible retained event tables
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS preproc_depression_anxiety_events;

CREATE TABLE preproc_depression_anxiety_events
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
    description
FROM preproc_confounder_events
WHERE confounder_name = 'depression_anxiety';

ALTER TABLE preproc_depression_anxiety_events
    ADD INDEX idx_dep_anx_events_patid_date (patid, eventdate),
    ADD INDEX idx_dep_anx_events_source (
        source_dataset,
        source_table,
        patid
    ),
    ADD INDEX idx_dep_anx_events_medcode (medcode);

DROP TABLE IF EXISTS preproc_smi_events;

CREATE TABLE preproc_smi_events
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
    description
FROM preproc_confounder_events
WHERE confounder_name = 'smi';

ALTER TABLE preproc_smi_events
    ADD INDEX idx_smi_events_patid_date (patid, eventdate),
    ADD INDEX idx_smi_events_source (
        source_dataset,
        source_table,
        patid
    ),
    ADD INDEX idx_smi_events_medcode (medcode);

DROP TABLE IF EXISTS preproc_tbi_events;

CREATE TABLE preproc_tbi_events
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
    description
FROM preproc_confounder_events
WHERE confounder_name = 'tbi';

ALTER TABLE preproc_tbi_events
    ADD INDEX idx_tbi_events_patid_date (patid, eventdate),
    ADD INDEX idx_tbi_events_source (
        source_dataset,
        source_table,
        patid
    ),
    ADD INDEX idx_tbi_events_medcode (medcode);

/* -------------------------------------------------------------------------
   4. Earliest retained event and mutually exclusive classification
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS confounder_first_events;

CREATE TABLE confounder_first_events
ENGINE=InnoDB
AS
SELECT
    ranked.confounder_name,
    ranked.patid,
    ranked.dementia_eventdate,
    ranked.eventdate,
    ranked.description,
    CASE
        WHEN ranked.eventdate < DATE_SUB(
                ranked.dementia_eventdate,
                INTERVAL 1095 DAY
             )
            THEN 'confounder'
        WHEN ranked.eventdate <= ranked.dementia_eventdate
            THEN 'exclusion'
        ELSE 'post_dementia'
    END AS event_window
FROM (
    SELECT
        e.confounder_name,
        e.patid,
        cb.dementia_eventdate,
        e.eventdate,
        e.description,
        ROW_NUMBER() OVER (
            PARTITION BY e.confounder_name, e.patid
            ORDER BY
                e.eventdate,
                e.source_rank,
                e.medcode,
                e.description
        ) AS event_rank
    FROM preproc_confounder_events AS e
    INNER JOIN preproc_base AS cb
        ON cb.patid = e.patid
    WHERE cb.dementia_eventdate IS NOT NULL
) AS ranked
WHERE ranked.event_rank = 1;

ALTER TABLE confounder_first_events
    ADD UNIQUE INDEX idx_first_confounder_name_patid (
        confounder_name,
        patid
    );

/* -------------------------------------------------------------------------
   5. Normalized patient-level confounder features
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS preproc_confounder_features_long;

CREATE TABLE preproc_confounder_features_long
ENGINE=InnoDB
AS
SELECT
    cb.patid,
    cb.dementia_eventdate,
    n.confounder_name,
    f.eventdate AS first_eventdate,
    f.description AS first_event_description,
    f.event_window,
    CASE WHEN f.event_window = 'confounder' THEN 1 ELSE 0 END
        AS confounder_flag,
    CASE WHEN f.event_window = 'confounder' THEN f.eventdate ELSE NULL END
        AS confounder_eventdate,
    CASE WHEN f.event_window = 'exclusion' THEN 1 ELSE 0 END
        AS exclusion_flag,
    CASE WHEN f.event_window = 'exclusion' THEN f.eventdate ELSE NULL END
        AS exclusion_eventdate,
    CASE WHEN f.event_window = 'post_dementia' THEN 1 ELSE 0 END
        AS post_dementia_flag,
    CASE
        WHEN f.event_window = 'post_dementia' THEN f.eventdate
        ELSE NULL
    END AS post_dementia_eventdate
FROM preproc_base AS cb
CROSS JOIN tmp_confounder_names AS n
LEFT JOIN confounder_first_events AS f
    ON f.patid = cb.patid
   AND f.confounder_name = n.confounder_name;

ALTER TABLE preproc_confounder_features_long
    ADD UNIQUE INDEX idx_confounder_features_name_patid (
        confounder_name,
        patid
    );

/* -------------------------------------------------------------------------
   6. R-compatible patient feature tables
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS feat_depression_anxiety;

CREATE TABLE feat_depression_anxiety
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    confounder_flag AS confounder_dep_anx,
    confounder_eventdate AS confounder_dep_anx_eventdate,
    exclusion_flag AS exclusion_dep_anx,
    exclusion_eventdate AS exclusion_dep_anx_eventdate,
    post_dementia_flag AS post_dem_dep_anx,
    post_dementia_eventdate AS post_dem_dep_anx_eventdate
FROM preproc_confounder_features_long
WHERE confounder_name = 'depression_anxiety';

ALTER TABLE feat_depression_anxiety
    ADD UNIQUE INDEX idx_feat_depression_anxiety_patid (patid);

DROP TABLE IF EXISTS feat_smi;

CREATE TABLE feat_smi
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    confounder_flag AS confounder_smi,
    confounder_eventdate AS confounder_smi_eventdate,
    exclusion_flag AS exclusion_smi,
    exclusion_eventdate AS exclusion_smi_eventdate,
    post_dementia_flag AS post_dem_smi,
    post_dementia_eventdate AS post_dem_smi_eventdate
FROM preproc_confounder_features_long
WHERE confounder_name = 'smi';

ALTER TABLE feat_smi
    ADD UNIQUE INDEX idx_feat_smi_patid (patid);

DROP TABLE IF EXISTS feat_tbi;

CREATE TABLE feat_tbi
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    confounder_flag AS confounder_tbi,
    confounder_eventdate AS confounder_tbi_eventdate,
    exclusion_flag AS exclusion_tbi,
    exclusion_eventdate AS exclusion_tbi_eventdate,
    post_dementia_flag AS post_dem_tbi,
    post_dementia_eventdate AS post_dem_tbi_eventdate
FROM preproc_confounder_features_long
WHERE confounder_name = 'tbi';

ALTER TABLE feat_tbi
    ADD UNIQUE INDEX idx_feat_tbi_patid (patid);

/* -------------------------------------------------------------------------
   7. QC summaries
   ------------------------------------------------------------------------- */

DROP VIEW IF EXISTS v_qc_confounder_event_counts;

CREATE VIEW v_qc_confounder_event_counts AS
SELECT
    confounder_name,
    source_table,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT patid) AS n_patients
FROM preproc_confounder_events
GROUP BY
    confounder_name,
    source_table;

DROP VIEW IF EXISTS v_qc_confounder_window_counts;

CREATE VIEW v_qc_confounder_window_counts AS
SELECT
    confounder_name,
    SUM(confounder_flag) AS n_confounder,
    SUM(exclusion_flag) AS n_exclusion,
    SUM(post_dementia_flag) AS n_post_dementia,
    SUM(first_eventdate IS NULL) AS n_without_event
FROM preproc_confounder_features_long
GROUP BY confounder_name;

/* -------------------------------------------------------------------------
   8. Explicit cleanup; these would also disappear at session end
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_confounder_names;
DROP TEMPORARY TABLE IF EXISTS tmp_confounder_codes;
