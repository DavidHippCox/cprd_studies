-- bmi_mariadb_pipeline_v1.sql
-- MariaDB 12.3.2 rewrite of bmi_sqlite_pipeline_v1.sql.
--
-- Main changes:
--   * Uses a session-scoped temporary codelist table.
--   * Replaces intermediate SQLite views with indexed temporary stages.
--   * Does not drop the source codelist table.
--   * Uses the existing pracid columns in Clinical and Additional.
--   * Avoids casts on join columns so source indexes remain usable.
--
-- Required source codelist:
--   bmi_codes_GOLD
--
-- Assumptions:
--   * Source and codelist join columns have compatible data types.
--   * bmi_codes_GOLD contains at most one row per medcode.
--   * preproc_base contains at most one row per patid.
--   * pc_clinical and pc_additional contain compatible pracid columns.
--   * pc_clinical and pc_additional are indexed on (adid, pracid).
--   * preproc_base.yob has the same comparison semantics as in
--     the original pipeline.

/* -------------------------------------------------------------------------
   1. Session-scoped codelist
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_bmi_cprd_codes;
CREATE TEMPORARY TABLE tmp_bmi_cprd_codes (
    medcode BIGINT UNSIGNED NOT NULL,
    description TEXT NULL,
    bmi_weight TINYINT UNSIGNED NULL,
    height TINYINT UNSIGNED NULL,
    PRIMARY KEY (medcode)
) ENGINE=InnoDB;

INSERT INTO tmp_bmi_cprd_codes (
    medcode,
    description,
    bmi_weight,
    height
)
SELECT
    medcode,
    description,
    bmi_weight,
    height
FROM bmi_codes_GOLD
WHERE medcode IS NOT NULL;

/* -------------------------------------------------------------------------
   2. Cohort-restricted Clinical and Additional stages
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_bmi_clinical_events;

CREATE TEMPORARY TABLE tmp_bmi_clinical_events
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
    cl.bmi_weight,
    cl.height
FROM pc_clinical AS c
INNER JOIN tmp_bmi_cprd_codes AS cl
    ON cl.medcode = c.medcode
INNER JOIN preproc_base AS cb
    ON cb.patid = c.patid;

ALTER TABLE tmp_bmi_clinical_events
    ADD INDEX idx_tmp_bmi_clinical_adid_pracid (adid, pracid);

DROP TEMPORARY TABLE IF EXISTS tmp_bmi_additional;

CREATE TEMPORARY TABLE tmp_bmi_additional
ENGINE=InnoDB
AS
SELECT DISTINCT
    a.pracid,
    a.adid,
    TRIM(CAST(a.data1 AS CHAR)) AS add_data1,
    TRIM(CAST(a.data3 AS CHAR)) AS add_data3,
    a.enttype
FROM pc_additional AS a
INNER JOIN preproc_base AS cb
    ON cb.patid = a.patid;

ALTER TABLE tmp_bmi_additional
    ADD INDEX idx_tmp_bmi_additional_adid_pracid (adid, pracid);

DROP TEMPORARY TABLE IF EXISTS tmp_bmi_clinical_keys;

CREATE TEMPORARY TABLE tmp_bmi_clinical_keys
ENGINE=InnoDB
AS
SELECT DISTINCT
    adid,
    pracid
FROM tmp_bmi_clinical_events
WHERE adid IS NOT NULL;

ALTER TABLE tmp_bmi_clinical_keys
    ADD INDEX idx_tmp_bmi_clinical_keys_adid_pracid (adid, pracid);

/* -------------------------------------------------------------------------
   3. Additional records absent from BMI Clinical events
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS bmi_additional_ent14_missing_in_clinical;

CREATE TABLE bmi_additional_ent14_missing_in_clinical
ENGINE=InnoDB
AS
SELECT
    a.pracid,
    a.adid,
    a.add_data1,
    a.add_data3,
    a.enttype
FROM tmp_bmi_additional AS a
LEFT JOIN tmp_bmi_clinical_keys AS ck
    ON ck.adid = a.adid
   AND ck.pracid = a.pracid
WHERE a.enttype = 14
  AND ck.adid IS NULL;

DROP TABLE IF EXISTS bmi_additional_ent13_missing_in_clinical;

CREATE TABLE bmi_additional_ent13_missing_in_clinical
ENGINE=InnoDB
AS
SELECT
    a.pracid,
    a.adid,
    a.add_data1,
    a.add_data3,
    a.enttype
FROM tmp_bmi_additional AS a
LEFT JOIN tmp_bmi_clinical_keys AS ck
    ON ck.adid = a.adid
   AND ck.pracid = a.pracid
WHERE a.enttype = 13
  AND ck.adid IS NULL;

/* -------------------------------------------------------------------------
   4. Thresholded Clinical and Additional BMI values
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_bmi_clinical_thresholded;

CREATE TEMPORARY TABLE tmp_bmi_clinical_thresholded
ENGINE=InnoDB
AS
SELECT
    r.patid,
    r.pracid,
    r.eventdate,
    r.medcode,
    r.enttype,
    r.adid,
    r.height_m,
    r.weight_kg,
    r.bmi,
    r.description,
    r.bmi_weight,
    r.height
FROM (
    SELECT
        c.patid,
        c.pracid,
        c.eventdate,
        c.medcode,
        c.enttype,
        c.adid,
        CASE
            WHEN a.enttype = 14 THEN CAST(
                NULLIF(a.add_data1, '') AS DECIMAL(10, 4)
            )
            ELSE NULL
        END AS height_m,
        CASE
            WHEN a.enttype = 13 THEN CAST(
                NULLIF(a.add_data1, '') AS DECIMAL(10, 4)
            )
            ELSE NULL
        END AS weight_kg,
        CASE
            WHEN a.enttype = 13 THEN CAST(
                NULLIF(a.add_data3, '') AS DECIMAL(10, 4)
            )
            ELSE NULL
        END AS bmi,
        c.description,
        c.bmi_weight,
        c.height
    FROM tmp_bmi_clinical_events AS c
    LEFT JOIN tmp_bmi_additional AS a
        ON a.adid = c.adid
       AND a.pracid = c.pracid
) AS r
WHERE NOT (
        COALESCE(r.bmi_weight, 0) = 1
        AND (r.bmi IS NULL OR r.bmi < 10 OR r.bmi > 80)
    )
  AND NOT (
        COALESCE(r.bmi_weight, 0) = 1
        AND (
            r.weight_kg IS NULL
            OR r.weight_kg < 30
            OR r.weight_kg > 300
        )
    )
  AND NOT (
        COALESCE(r.height, 0) = 1
        AND (
            r.height_m IS NULL
            OR r.height_m < 1.3
            OR r.height_m > 2.2
        )
    );

ALTER TABLE tmp_bmi_clinical_thresholded
    ADD INDEX idx_tmp_bmi_thresholded_patid (patid);

/* -------------------------------------------------------------------------
   5. Patient-level BMI derivation status
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_bmi_patient_derivation_status;

CREATE TEMPORARY TABLE tmp_bmi_patient_derivation_status
ENGINE=InnoDB
AS
SELECT
    patid,
    CASE
        WHEN MAX(CASE WHEN bmi IS NOT NULL THEN 1 ELSE 0 END) = 1
          OR (
                MAX(
                    CASE WHEN height_m IS NOT NULL THEN 1 ELSE 0 END
                ) = 1
                AND MAX(
                    CASE WHEN weight_kg IS NOT NULL THEN 1 ELSE 0 END
                ) = 1
             )
            THEN 0
        ELSE 1
    END AS cannot_derive_bmi
FROM tmp_bmi_clinical_thresholded
GROUP BY patid;

ALTER TABLE tmp_bmi_patient_derivation_status
    ADD UNIQUE INDEX idx_tmp_bmi_derivation_patid (patid);

DROP TABLE IF EXISTS bmi_records_cannot_derive_bmi;

CREATE TABLE bmi_records_cannot_derive_bmi
ENGINE=InnoDB
AS
SELECT
    c.medcode,
    c.patid,
    c.eventdate,
    c.enttype,
    c.adid,
    c.pracid,
    c.height_m,
    c.weight_kg,
    c.bmi,
    c.bmi_weight,
    c.height
FROM tmp_bmi_clinical_thresholded AS c
INNER JOIN tmp_bmi_patient_derivation_status AS s
    ON s.patid = c.patid
WHERE s.cannot_derive_bmi = 1;

/* -------------------------------------------------------------------------
   6. All BMI events plus the lifetime/time-in-practice flag
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS bmi_log_events;

CREATE TABLE bmi_log_events
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
    e.height_m,
    e.weight_kg,
    e.bmi,
    e.description,
    e.bmi_weight,
    e.height,
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
        c.height_m,
        c.weight_kg,
        c.bmi,
        c.description,
        c.bmi_weight,
        c.height
    FROM tmp_bmi_clinical_thresholded AS c
    INNER JOIN tmp_bmi_patient_derivation_status AS s
        ON s.patid = c.patid
    WHERE s.cannot_derive_bmi = 0

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
        CAST(NULL AS DECIMAL(10, 4)) AS height_m,
        CAST(NULL AS DECIMAL(10, 4)) AS weight_kg,
        CAST(NULL AS DECIMAL(10, 4)) AS bmi,
        cl.description,
        cl.bmi_weight,
        cl.height
    FROM pc_test AS t
    INNER JOIN tmp_bmi_cprd_codes AS cl
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
        CAST(NULL AS DECIMAL(10, 4)) AS height_m,
        CAST(NULL AS DECIMAL(10, 4)) AS weight_kg,
        CAST(NULL AS DECIMAL(10, 4)) AS bmi,
        cl.description,
        cl.bmi_weight,
        cl.height
    FROM pc_referral AS r
    INNER JOIN tmp_bmi_cprd_codes AS cl
        ON cl.medcode = r.medcode
) AS e
INNER JOIN preproc_base AS cb
    ON cb.patid = e.patid
WHERE e.eventdate IS NOT NULL;

ALTER TABLE bmi_log_events
    ADD INDEX idx_bmi_log_patid_eventdate (patid, eventdate),
    ADD INDEX idx_bmi_log_source (source_dataset, source_table);

/* -------------------------------------------------------------------------
   7. Retained BMI events
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS preproc_bmi_events;

CREATE TABLE preproc_bmi_events
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
    height_m,
    weight_kg,
    bmi,
    description,
    bmi_weight,
    height
FROM bmi_log_events
WHERE keep_flag = 1;

ALTER TABLE preproc_bmi_events
    ADD INDEX idx_bmi_events_patid_eventdate (patid, eventdate),
    ADD INDEX idx_bmi_events_source (
        source_dataset,
        source_table,
        patid
    ),
    ADD INDEX idx_bmi_events_medcode (medcode);

/* -------------------------------------------------------------------------
   8. QC summaries
   ------------------------------------------------------------------------- */

DROP VIEW IF EXISTS v_qc_bmi_event_counts;

CREATE VIEW v_qc_bmi_event_counts AS
SELECT
    source_dataset,
    source_table,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT patid) AS n_patients
FROM preproc_bmi_events
GROUP BY
    source_dataset,
    source_table;

DROP VIEW IF EXISTS v_qc_bmi_cannot_derive_count;

CREATE VIEW v_qc_bmi_cannot_derive_count AS
SELECT
    COUNT(*) AS n_rows,
    COUNT(DISTINCT patid) AS n_patients
FROM bmi_records_cannot_derive_bmi;

DROP VIEW IF EXISTS v_qc_bmi_additional_missing_counts;

CREATE VIEW v_qc_bmi_additional_missing_counts AS
SELECT
    'enttype_14' AS enttype,
    COUNT(*) AS n_rows
FROM bmi_additional_ent14_missing_in_clinical
UNION ALL
SELECT
    'enttype_13' AS enttype,
    COUNT(*) AS n_rows
FROM bmi_additional_ent13_missing_in_clinical;

/* -------------------------------------------------------------------------
   9. Explicit cleanup; these would also disappear at session end
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_bmi_patient_derivation_status;
DROP TEMPORARY TABLE IF EXISTS tmp_bmi_clinical_thresholded;
DROP TEMPORARY TABLE IF EXISTS tmp_bmi_clinical_keys;
DROP TEMPORARY TABLE IF EXISTS tmp_bmi_additional;
DROP TEMPORARY TABLE IF EXISTS tmp_bmi_clinical_events;
DROP TEMPORARY TABLE IF EXISTS tmp_bmi_cprd_codes;
