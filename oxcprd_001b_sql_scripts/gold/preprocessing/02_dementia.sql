-- dementia_mariadb_pipeline_v2.sql
-- MariaDB 12.3.2 rewrite of dementia_sqlite_pipeline_v1.sql.
--
-- Main changes:
--   * Uses session-scoped temporary codelist tables.
--   * Removes all intermediate views and repeated codelist joins.
--   * Does not drop the source codelist tables.
--   * Avoids casts on source join columns so indexes remain usable.
--   * Uses the supplied GOLD codelist table names.
--
-- Required source codelists:
--   v1_5_dementia_codes_GOLD
--   dementia_codes_icd10
--   v1_2_dementia_drug_GOLD
--
-- Assumptions:
--   * Source and codelist join columns have compatible data types.
--   * preproc_patient_candidates.yob has the same comparison semantics
--     as in the original pipeline.

/* -------------------------------------------------------------------------
   1. Session-scoped codelists
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_dementia_cprd_codes;
CREATE TEMPORARY TABLE tmp_dementia_cprd_codes (
    medcode BIGINT UNSIGNED NOT NULL,
    description TEXT NULL,
    subtype VARCHAR(255) NULL,
    PRIMARY KEY (medcode)
) ENGINE=InnoDB;

INSERT INTO tmp_dementia_cprd_codes (
    medcode,
    description,
    subtype
)
SELECT
    medcode,
    readterm,
    subtype
FROM v1_5_dementia_codes_GOLD
WHERE medcode IS NOT NULL;

DROP TEMPORARY TABLE IF EXISTS tmp_dementia_icd10_codes;
CREATE TEMPORARY TABLE tmp_dementia_icd10_codes (
    icd10 VARCHAR(9) NOT NULL,
    description TEXT NULL,
    subtype VARCHAR(255) NULL,
    PRIMARY KEY (icd10)
) ENGINE=InnoDB;

INSERT INTO tmp_dementia_icd10_codes (
    icd10,
    description,
    subtype
)
SELECT
    icd10,
    description,
    subtype
FROM dementia_codes_icd10
WHERE icd10 IS NOT NULL
  AND icd10 <> '';

DROP TEMPORARY TABLE IF EXISTS tmp_dementia_drug_codes;
CREATE TEMPORARY TABLE tmp_dementia_drug_codes (
    prodcode BIGINT UNSIGNED NOT NULL,
    description TEXT NULL,
    subtype VARCHAR(255) NOT NULL,
    PRIMARY KEY (prodcode)
) ENGINE=InnoDB;

INSERT INTO tmp_dementia_drug_codes (
    prodcode,
    description,
    subtype
)
SELECT
    prodcode,
    productname,
    'dementia_drug'
FROM v1_2_dementia_drug_GOLD
WHERE prodcode IS NOT NULL;

/* -------------------------------------------------------------------------
   2. All dementia events plus the lifetime/time-in-practice flag
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS dementia_log_events;

CREATE TABLE dementia_log_events
ENGINE=InnoDB
AS
SELECT
    e.source_table,
    e.source_dataset,
    e.patid,
    e.eventdate,
    e.medcode,
    e.icd10,
    e.prodcode,
    e.enttype,
    e.adid,
    e.description,
    e.subtype,
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
        'clinical' AS source_table,
        'cprd' AS source_dataset,
        c.patid,
        c.eventdate,
        c.medcode,
        CAST(NULL AS CHAR(9)) AS icd10,
        CAST(NULL AS UNSIGNED) AS prodcode,
        c.enttype,
        c.adid,
        cl.description,
        cl.subtype
    FROM pc_clinical AS c
    INNER JOIN tmp_dementia_cprd_codes AS cl
        ON cl.medcode = c.medcode

    UNION ALL

    SELECT
        'test' AS source_table,
        'cprd' AS source_dataset,
        t.patid,
        t.eventdate,
        t.medcode,
        CAST(NULL AS CHAR(9)) AS icd10,
        CAST(NULL AS UNSIGNED) AS prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        cl.description,
        cl.subtype
    FROM pc_test AS t
    INNER JOIN tmp_dementia_cprd_codes AS cl
        ON cl.medcode = t.medcode

    UNION ALL

    SELECT
        'referral' AS source_table,
        'cprd' AS source_dataset,
        r.patid,
        r.eventdate,
        r.medcode,
        CAST(NULL AS CHAR(9)) AS icd10,
        CAST(NULL AS UNSIGNED) AS prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        cl.description,
        cl.subtype
    FROM pc_referral AS r
    INNER JOIN tmp_dementia_cprd_codes AS cl
        ON cl.medcode = r.medcode

    UNION ALL

    SELECT
        'therapy' AS source_table,
        'cprd' AS source_dataset,
        th.patid,
        th.eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        CAST(NULL AS CHAR(9)) AS icd10,
        th.prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        dl.description,
        dl.subtype
    FROM pc_therapy AS th
    INNER JOIN tmp_dementia_drug_codes AS dl
        ON dl.prodcode = th.prodcode

    UNION ALL

    SELECT
        'hes_apc_diag_epi' AS source_table,
        'hes' AS source_dataset,
        h.patid,
        h.epistart AS eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        h.icd AS icd10,
        CAST(NULL AS UNSIGNED) AS prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        il.description,
        il.subtype
    FROM linked_hes_diagnosis_epi AS h
    INNER JOIN tmp_dementia_icd10_codes AS il
        ON il.icd10 = h.icd

    UNION ALL

    SELECT
        'hes_apc_diag_hosp' AS source_table,
        'hes' AS source_dataset,
        h.patid,
        h.admidate AS eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        h.icd AS icd10,
        CAST(NULL AS UNSIGNED) AS prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        il.description,
        il.subtype
    FROM linked_hes_diagnosis_hosp AS h
    INNER JOIN tmp_dementia_icd10_codes AS il
        ON il.icd10 = h.icd

    UNION ALL

    SELECT
        'hes_apc_primary_diag_hosp' AS source_table,
        'hes' AS source_dataset,
        h.patid,
        h.admidate AS eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        h.icd_primary AS icd10,
        CAST(NULL AS UNSIGNED) AS prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        il.description,
        il.subtype
    FROM linked_hes_primary_diag_hosp AS h
    INNER JOIN tmp_dementia_icd10_codes AS il
        ON il.icd10 = h.icd_primary

    UNION ALL

    SELECT
        'hes_op' AS source_table,
        'hes' AS source_dataset,
        c.patid,
        a.apptdate AS eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        c.icd AS icd10,
        CAST(NULL AS UNSIGNED) AS prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        il.description,
        il.subtype
    FROM linked_hesop_clinical AS c
    INNER JOIN linked_hesop_appointment AS a
        ON a.patid = c.patid
       AND a.attendkey = c.attendkey
    INNER JOIN tmp_dementia_icd10_codes AS il
        ON il.icd10 = c.icd
) AS e
LEFT JOIN preproc_patient_candidates AS p
    ON p.patid = e.patid
WHERE e.eventdate IS NOT NULL;

ALTER TABLE dementia_log_events
    ADD INDEX idx_dementia_log_patid_eventdate (patid, eventdate),
    ADD INDEX idx_dementia_log_source (source_dataset, source_table);

/* -------------------------------------------------------------------------
   3. Retained dementia events
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS preproc_dementia_events;

CREATE TABLE preproc_dementia_events
ENGINE=InnoDB
AS
SELECT
    source_table,
    source_dataset,
    patid,
    eventdate,
    medcode,
    icd10,
    prodcode,
    enttype,
    adid,
    description,
    subtype
FROM dementia_log_events
WHERE keep_flag = 1;

ALTER TABLE preproc_dementia_events
    ADD INDEX idx_dementia_events_patid_eventdate (patid, eventdate),
    ADD INDEX idx_dementia_events_source (source_dataset, source_table),
    ADD INDEX idx_dementia_events_medcode (medcode),
    ADD INDEX idx_dementia_events_icd10 (icd10),
    ADD INDEX idx_dementia_events_prodcode (prodcode);

/* -------------------------------------------------------------------------
   4. QC summary
   ------------------------------------------------------------------------- */

DROP VIEW IF EXISTS v_qc_dementia_event_counts;

CREATE VIEW v_qc_dementia_event_counts AS
SELECT
    source_dataset,
    source_table,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT patid) AS n_patients
FROM preproc_dementia_events
GROUP BY
    source_dataset,
    source_table;

/* -------------------------------------------------------------------------
   5. Explicit cleanup; these would also disappear at session end
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_dementia_cprd_codes;
DROP TEMPORARY TABLE IF EXISTS tmp_dementia_icd10_codes;
DROP TEMPORARY TABLE IF EXISTS tmp_dementia_drug_codes;
