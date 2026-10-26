-- Authored by David Hippisley-Cox
-- project: gold_oxcprd_001b
-- analysis plan version: NA
-- alcohol_mariadb_pipeline_v1.sql
-- MariaDB 12.3.2 rewrite of alcohol_sqlite_pipeline_v2.sql.
--
-- Main changes:
--   * Uses session-scoped temporary codelist tables.
--   * Replaces intermediate SQLite views with one filtered clinical stage.
--   * Materialises the Additional enttype 5 QC output.
--   * Does not drop the source codelist tables.
--   * Avoids casts on codelist and HES join columns so indexes remain usable.
--   * Retains the SQLite output columns and lifetime/time-in-practice logic.
--
-- Required source codelists:
--   alcohol_codes_GOLD
--   alcohol_codes_icd10
--
-- Assumptions:
--   * Source and codelist join columns have compatible data types.
--   * Each source codelist contains at most one row per code.
--   * preproc_patient_candidates.yob has the same comparison semantics
--     as in the original pipeline.
--   * pc_clinical and pc_additional already contain compatible pracid
--     columns.
--   * pc_additional is indexed on (pracid, adid).

/* -------------------------------------------------------------------------
   1. Session-scoped codelists
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_alcohol_cprd_codes;
CREATE TEMPORARY TABLE tmp_alcohol_cprd_codes (
    medcode BIGINT UNSIGNED NOT NULL,
    description TEXT NULL,
    alc_category VARCHAR(255) NULL,
    strict_phenotype VARCHAR(255) NULL,
    PRIMARY KEY (medcode)
) ENGINE=InnoDB;

INSERT INTO tmp_alcohol_cprd_codes (
    medcode,
    description,
    alc_category,
    strict_phenotype
)
SELECT
    medcode,
    readterm,
    alc_category,
    strict_phenotype
FROM v2_2_alcohol_codes_GOLD
WHERE medcode IS NOT NULL;

DROP TEMPORARY TABLE IF EXISTS tmp_alcohol_icd10_codes;
CREATE TEMPORARY TABLE tmp_alcohol_icd10_codes (
    icd10 VARCHAR(9) NOT NULL,
    description TEXT NULL,
    alc_category VARCHAR(255) NULL,
    strict_phenotype VARCHAR(255) NULL,
    PRIMARY KEY (icd10)
) ENGINE=InnoDB;

INSERT INTO tmp_alcohol_icd10_codes (
    icd10,
    description,
    alc_category,
    strict_phenotype
)
SELECT
    icd10,
    description,
    alc_category,
    strict_phenotype
FROM alcohol_codes_icd10
WHERE icd10 IS NOT NULL
  AND icd10 <> '';

/* -------------------------------------------------------------------------
   2. Filtered clinical events
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_alcohol_clinical_events;

CREATE TEMPORARY TABLE tmp_alcohol_clinical_events
ENGINE=InnoDB
AS
SELECT
    c.patid,
    c.eventdate,
    c.medcode,
    c.enttype,
    c.adid,
    c.pracid,
    cl.description,
    cl.alc_category,
    cl.strict_phenotype
FROM pc_clinical AS c
INNER JOIN tmp_alcohol_cprd_codes AS cl
    ON cl.medcode = c.medcode;

ALTER TABLE tmp_alcohol_clinical_events
    ADD INDEX idx_tmp_alcohol_clinical_pracid_adid (pracid, adid),
    ADD INDEX idx_tmp_alcohol_clinical_patid_eventdate (patid, eventdate);

/* -------------------------------------------------------------------------
   3. Additional enttype 5 records absent from alcohol clinical events
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS qc_alcohol_additional_ent5_missing;

CREATE TABLE qc_alcohol_additional_ent5_missing
ENGINE=InnoDB
AS
SELECT
    a.pracid,
    a.adid,
    a.data1 AS add_alcstatus_raw,
    a.data2 AS add_upw_raw,
    a.enttype
FROM pc_additional AS a
LEFT JOIN (
    SELECT DISTINCT
        pracid,
        adid
    FROM tmp_alcohol_clinical_events
) AS ck
    ON ck.adid = a.adid
   AND ck.pracid = a.pracid
WHERE a.enttype = 5
  AND ck.adid IS NULL;

ALTER TABLE qc_alcohol_additional_ent5_missing
    ADD INDEX idx_qc_alcohol_additional_pracid_adid (pracid, adid);

/* -------------------------------------------------------------------------
   4. All alcohol events plus the lifetime/time-in-practice flag
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS alcohol_log_events;

CREATE TABLE alcohol_log_events
ENGINE=InnoDB
AS
SELECT
    e.source_table,
    e.source_dataset,
    e.patid,
    e.eventdate,
    e.medcode,
    e.icd10,
    e.enttype,
    e.adid,
    e.add_alcstatus,
    e.add_upd,
    e.description,
    e.alc_category,
    e.strict_phenotype,
    p.yob,
    p.tod,
    p.merged_death,
    CASE
        WHEN e.source_dataset = 'hes' THEN 1
        WHEN e.eventdate > p.yob
         AND (p.tod IS NULL OR e.eventdate <= p.tod)
         AND (
                p.merged_death IS NULL
                OR e.eventdate <= p.merged_death
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
        CAST(NULL AS CHAR(9)) AS icd10,
        c.enttype,
        c.adid,
        CASE CAST(a.data1 AS CHAR)
            WHEN '0' THEN 'not-recorded'
            WHEN '1' THEN 'current-drinker'
            WHEN '2' THEN 'non-drinker'
            WHEN '3' THEN 'ex-drinker'
            ELSE NULL
        END AS add_alcstatus,
        ROUND(
            CAST(NULLIF(TRIM(a.data2), '') AS DECIMAL(18, 6)) / 7,
            2
        ) AS add_upd,
        c.description,
        c.alc_category,
        c.strict_phenotype
    FROM tmp_alcohol_clinical_events AS c
    LEFT JOIN pc_additional AS a
        ON a.adid = c.adid
       AND a.pracid = c.pracid

    UNION ALL

    SELECT
        'test' AS source_table,
        'cprd' AS source_dataset,
        t.patid,
        t.eventdate,
        t.medcode,
        CAST(NULL AS CHAR(9)) AS icd10,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        CAST(NULL AS CHAR(15)) AS add_alcstatus,
        CAST(NULL AS DECIMAL(18, 2)) AS add_upd,
        cl.description,
        cl.alc_category,
        cl.strict_phenotype
    FROM pc_test AS t
    INNER JOIN tmp_alcohol_cprd_codes AS cl
        ON cl.medcode = t.medcode

    UNION ALL

    SELECT
        'referral' AS source_table,
        'cprd' AS source_dataset,
        r.patid,
        r.eventdate,
        r.medcode,
        CAST(NULL AS CHAR(9)) AS icd10,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        CAST(NULL AS CHAR(15)) AS add_alcstatus,
        CAST(NULL AS DECIMAL(18, 2)) AS add_upd,
        cl.description,
        cl.alc_category,
        cl.strict_phenotype
    FROM pc_referral AS r
    INNER JOIN tmp_alcohol_cprd_codes AS cl
        ON cl.medcode = r.medcode

    UNION ALL

    SELECT
        'hes_apc_diag_epi' AS source_table,
        'hes' AS source_dataset,
        h.patid,
        h.epistart AS eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        h.icd AS icd10,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        CAST(NULL AS CHAR(15)) AS add_alcstatus,
        CAST(NULL AS DECIMAL(18, 2)) AS add_upd,
        il.description,
        il.alc_category,
        il.strict_phenotype
    FROM linked_hes_diagnosis_epi AS h
    INNER JOIN tmp_alcohol_icd10_codes AS il
        ON il.icd10 = h.icd

    UNION ALL

    SELECT
        'hes_apc_diag_hosp' AS source_table,
        'hes' AS source_dataset,
        h.patid,
        h.admidate AS eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        h.icd AS icd10,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        CAST(NULL AS CHAR(15)) AS add_alcstatus,
        CAST(NULL AS DECIMAL(18, 2)) AS add_upd,
        il.description,
        il.alc_category,
        il.strict_phenotype
    FROM linked_hes_diagnosis_hosp AS h
    INNER JOIN tmp_alcohol_icd10_codes AS il
        ON il.icd10 = h.icd

    UNION ALL

    SELECT
        'hes_apc_primary_diag_hosp' AS source_table,
        'hes' AS source_dataset,
        h.patid,
        h.admidate AS eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        h.icd_primary AS icd10,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        CAST(NULL AS CHAR(15)) AS add_alcstatus,
        CAST(NULL AS DECIMAL(18, 2)) AS add_upd,
        il.description,
        il.alc_category,
        il.strict_phenotype
    FROM linked_hes_primary_diag_hosp AS h
    INNER JOIN tmp_alcohol_icd10_codes AS il
        ON il.icd10 = h.icd_primary

    UNION ALL

    SELECT
        'hes_op' AS source_table,
        'hes' AS source_dataset,
        c.patid,
        a.apptdate AS eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        c.icd AS icd10,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        CAST(NULL AS CHAR(15)) AS add_alcstatus,
        CAST(NULL AS DECIMAL(18, 2)) AS add_upd,
        il.description,
        il.alc_category,
        il.strict_phenotype
    FROM linked_hesop_clinical AS c
    INNER JOIN linked_hesop_appointment AS a
        ON a.patid = c.patid
       AND a.attendkey = c.attendkey
    INNER JOIN tmp_alcohol_icd10_codes AS il
        ON il.icd10 = c.icd
) AS e
LEFT JOIN preproc_patient_candidates AS p
    ON p.patid = e.patid
WHERE e.eventdate IS NOT NULL;

ALTER TABLE alcohol_log_events
    ADD INDEX idx_alcohol_log_patid_eventdate (patid, eventdate),
    ADD INDEX idx_alcohol_log_source (source_dataset, source_table);

/* -------------------------------------------------------------------------
   5. Retained alcohol events
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS preproc_alcohol_events;

CREATE TABLE preproc_alcohol_events
ENGINE=InnoDB
AS
SELECT
    source_table,
    source_dataset,
    patid,
    eventdate,
    medcode,
    icd10,
    enttype,
    adid,
    add_alcstatus,
    add_upd,
    description,
    alc_category,
    strict_phenotype
FROM alcohol_log_events
WHERE keep_flag = 1;

ALTER TABLE preproc_alcohol_events
    ADD INDEX idx_alcohol_events_patid_eventdate (patid, eventdate),
    ADD INDEX idx_alcohol_events_source (source_dataset, source_table),
    ADD INDEX idx_alcohol_events_medcode (medcode),
    ADD INDEX idx_alcohol_events_icd10 (icd10);

/* -------------------------------------------------------------------------
   6. QC summary
   ------------------------------------------------------------------------- */

DROP VIEW IF EXISTS v_qc_alcohol_event_counts;

CREATE VIEW v_qc_alcohol_event_counts AS
SELECT
    source_dataset,
    source_table,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT patid) AS n_patients
FROM preproc_alcohol_events
GROUP BY
    source_dataset,
    source_table;

/* -------------------------------------------------------------------------
   7. Explicit cleanup; these would also disappear at session end
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_alcohol_clinical_events;
DROP TEMPORARY TABLE IF EXISTS tmp_alcohol_cprd_codes;
DROP TEMPORARY TABLE IF EXISTS tmp_alcohol_icd10_codes;
