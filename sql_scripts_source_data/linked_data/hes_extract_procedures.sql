-- HES extraction procedures using the Aurum extraction call convention
-- Target database: MariaDB 12.3.2
--
-- Run this script while the HES source database is selected:
--
--     USE hes_database;
--
-- Source tables are resolved in the current database. The patient/code
-- input table and output table are resolved in p_project_schema, typically
-- a database named aurum_oxcprd_xxxx.
--
-- p_select_list is a trusted SQL fragment. It may be '*' or an unqualified
-- list such as 'patid, epistart, ICD'. The source table is the only table in
-- the outer SELECT, so unqualified source columns are not ambiguous.

-- ============================================================
-- Materialized HES outpatient clinical table with appointment date
-- ============================================================
-- This table contains every column from hesop_clinical plus apptdate from
-- hesop_appointment. Re-run this block to rebuild it after source updates.

DROP TABLE IF EXISTS hesop_clinical_apptdate;

CREATE TABLE hesop_clinical_apptdate (
    patid BIGINT UNSIGNED NOT NULL,
    attendkey BIGINT UNSIGNED NOT NULL,
    diagnosis CHAR(9),
    icdx CHAR(9),
    icd CHAR(9),
    diag_order SMALLINT,
    tretspef CHAR(9),
    mainspef CHAR(9),
    apptdate DATE,
    PRIMARY KEY (patid, attendkey),
    KEY idx_hesop_clinical_apptdate_icd_date (icd, apptdate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO hesop_clinical_apptdate (
    patid,
    attendkey,
    diagnosis,
    icdx,
    icd,
    diag_order,
    tretspef,
    mainspef,
    apptdate
)
SELECT
    c.patid,
    c.attendkey,
    c.diagnosis,
    c.icdx,
    c.icd,
    c.diag_order,
    c.tretspef,
    c.mainspef,
    a.apptdate
FROM hesop_clinical AS c
INNER JOIN hesop_appointment AS a
    ON a.patid = c.patid
   AND a.attendkey = c.attendkey;

-- ============================================================
-- Extraction procedures
-- ============================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS extract_by_patid_to_table$$
CREATE PROCEDURE extract_by_patid_to_table(
    IN p_source_table VARCHAR(64),
    IN p_project_schema VARCHAR(64),
    IN p_patid_table VARCHAR(64),
    IN p_select_list LONGTEXT,
    IN p_output_table VARCHAR(64),
    IN p_replace_existing BOOLEAN
)
proc: BEGIN
    DECLARE v_source_table VARCHAR(130);
    DECLARE v_patid_table VARCHAR(261);
    DECLARE v_output_table VARCHAR(261);
    DECLARE v_sql LONGTEXT;
    DECLARE v_output_exists INT DEFAULT 0;

    IF p_source_table IS NULL OR p_source_table = ''
       OR p_project_schema IS NULL OR p_project_schema = ''
       OR p_patid_table IS NULL OR p_patid_table = ''
       OR p_output_table IS NULL OR p_output_table = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Table and database parameters must not be empty';
    END IF;

    IF DATABASE() IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Select the HES source database before calling procedure';
    END IF;

    IF p_select_list IS NULL OR TRIM(p_select_list) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_select_list must not be empty';
    END IF;

    IF p_replace_existing IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_replace_existing must be TRUE or FALSE';
    END IF;

    IF p_source_table NOT REGEXP '^[0-9A-Za-z_$]+$'
       OR p_project_schema NOT REGEXP '^[0-9A-Za-z_$]+$'
       OR p_patid_table NOT REGEXP '^[0-9A-Za-z_$]+$'
       OR p_output_table NOT REGEXP '^[0-9A-Za-z_$]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid database or table identifier';
    END IF;

    -- Reject obvious statement separators and SQL comment tokens.
    -- This does not make an arbitrary select list safe for untrusted users.
    IF p_select_list REGEXP ';|--|/\\*|\\*/|#[[:space:]]' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'p_select_list contains a prohibited SQL token';
    END IF;

    IF p_output_table = p_patid_table THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Output table must differ from patient input table';
    END IF;

    IF p_project_schema = DATABASE()
       AND p_output_table = p_source_table THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Output table must differ from source table';
    END IF;

    SELECT COUNT(*)
      INTO v_output_exists
      FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = p_project_schema
       AND TABLE_NAME = p_output_table;

    IF v_output_exists > 0 AND NOT p_replace_existing THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Output table exists and replacement was not requested';
    END IF;

    SET v_source_table = CONCAT(
        '`', REPLACE(p_source_table, '`', '``'), '`'
    );
    SET v_patid_table = CONCAT(
        '`', REPLACE(p_project_schema, '`', '``'), '`.',
        '`', REPLACE(p_patid_table, '`', '``'), '`'
    );
    SET v_output_table = CONCAT(
        '`', REPLACE(p_project_schema, '`', '``'), '`.',
        '`', REPLACE(p_output_table, '`', '``'), '`'
    );

    IF v_output_exists > 0 THEN
        SET v_sql = CONCAT('DROP TABLE ', v_output_table);
        PREPARE stmt FROM v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SET v_sql = CONCAT(
        'CREATE TABLE ', v_output_table, ' AS ',
        'SELECT ', p_select_list, ' ',
        'FROM ', v_source_table, ' AS s ',
        'WHERE EXISTS (',
        'SELECT 1 ',
        'FROM ', v_patid_table, ' AS p ',
        'WHERE p.patid = s.patid',
        ')'
    );

    PREPARE stmt FROM v_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DROP PROCEDURE IF EXISTS extract_by_code_to_table$$
CREATE PROCEDURE extract_by_code_to_table(
    IN p_source_table VARCHAR(64),
    IN p_project_schema VARCHAR(64),
    IN p_codelist_table VARCHAR(64),
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_select_list LONGTEXT,
    IN p_output_table VARCHAR(64),
    IN p_replace_existing BOOLEAN
)
proc: BEGIN
    DECLARE v_source_table VARCHAR(130);
    DECLARE v_codelist_table VARCHAR(261);
    DECLARE v_output_table VARCHAR(261);
    DECLARE v_code_column VARCHAR(130);
    DECLARE v_date_column VARCHAR(130);
    DECLARE v_source_table_norm VARCHAR(64);
    DECLARE v_sql LONGTEXT;
    DECLARE v_output_exists INT DEFAULT 0;

    IF p_source_table IS NULL OR p_source_table = ''
       OR p_project_schema IS NULL OR p_project_schema = ''
       OR p_codelist_table IS NULL OR p_codelist_table = ''
       OR p_output_table IS NULL OR p_output_table = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Table and database parameters must not be empty';
    END IF;

    IF DATABASE() IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Select the HES source database before calling procedure';
    END IF;

    IF p_select_list IS NULL OR TRIM(p_select_list) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_select_list must not be empty';
    END IF;

    IF p_replace_existing IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_replace_existing must be TRUE or FALSE';
    END IF;

    IF p_start_date IS NOT NULL
       AND p_end_date IS NOT NULL
       AND p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'p_start_date must be on or before p_end_date';
    END IF;

    IF p_source_table NOT REGEXP '^[0-9A-Za-z_$]+$'
       OR p_project_schema NOT REGEXP '^[0-9A-Za-z_$]+$'
       OR p_codelist_table NOT REGEXP '^[0-9A-Za-z_$]+$'
       OR p_output_table NOT REGEXP '^[0-9A-Za-z_$]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid database or table identifier';
    END IF;

    IF p_select_list REGEXP ';|--|/\\*|\\*/|#[[:space:]]' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'p_select_list contains a prohibited SQL token';
    END IF;

    IF p_output_table = p_codelist_table THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Output table must differ from codelist table';
    END IF;

    IF p_project_schema = DATABASE()
       AND p_output_table = p_source_table THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Output table must differ from source table';
    END IF;

    -- The Aurum-style signature does not expose code/date column names.
    -- Resolve them from the supported HES source table name instead.
    SET v_source_table_norm = LOWER(p_source_table);

    CASE v_source_table_norm
        WHEN 'hes_diagnosis_epi' THEN
            SET v_code_column = '`ICD`';
            SET v_date_column = '`epistart`';
        WHEN 'hes_diagnosis_hosp' THEN
            SET v_code_column = '`ICD`';
            SET v_date_column = '`admidate`';
        WHEN 'hes_primary_diag_hosp' THEN
            SET v_code_column = '`ICD_PRIMARY`';
            SET v_date_column = '`admidate`';
        WHEN 'hesop_clinical_apptdate' THEN
            SET v_code_column = '`icd`';
            SET v_date_column = '`apptdate`';
        ELSE
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'Unsupported source table for ICD-10/date extraction';
    END CASE;

    SELECT COUNT(*)
      INTO v_output_exists
      FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = p_project_schema
       AND TABLE_NAME = p_output_table;

    IF v_output_exists > 0 AND NOT p_replace_existing THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Output table exists and replacement was not requested';
    END IF;

    SET v_source_table = CONCAT(
        '`', REPLACE(p_source_table, '`', '``'), '`'
    );
    SET v_codelist_table = CONCAT(
        '`', REPLACE(p_project_schema, '`', '``'), '`.',
        '`', REPLACE(p_codelist_table, '`', '``'), '`'
    );
    SET v_output_table = CONCAT(
        '`', REPLACE(p_project_schema, '`', '``'), '`.',
        '`', REPLACE(p_output_table, '`', '``'), '`'
    );

    IF v_output_exists > 0 THEN
        SET v_sql = CONCAT('DROP TABLE ', v_output_table);
        PREPARE stmt FROM v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SET @hes_start_date = p_start_date;
    SET @hes_end_date = p_end_date;

    SET v_sql = CONCAT(
        'CREATE TABLE ', v_output_table, ' AS ',
        'SELECT ', p_select_list, ' ',
        'FROM ', v_source_table, ' AS s ',
        'WHERE EXISTS (',
        'SELECT 1 ',
        'FROM ', v_codelist_table, ' AS cl ',
        'WHERE cl.icd10 = s.', v_code_column,
        ') ',
        'AND (? IS NULL OR s.', v_date_column, ' >= ?) ',
        'AND (? IS NULL OR s.', v_date_column, ' <= ?)'
    );

    PREPARE stmt FROM v_sql;
    EXECUTE stmt USING
        @hes_start_date,
        @hes_start_date,
        @hes_end_date,
        @hes_end_date;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- ============================================================
-- Recommended source indexes
-- ============================================================
-- The primary key on hesop_clinical_apptdate starts with patid, so a
-- separate patient index is unnecessary for that table.

CREATE INDEX IF NOT EXISTS idx_hes_diagnosis_epi_patid
    ON hes_diagnosis_epi (patid);
CREATE INDEX IF NOT EXISTS idx_hes_diagnosis_epi_icd_date
    ON hes_diagnosis_epi (ICD, epistart);

CREATE INDEX IF NOT EXISTS idx_hes_diagnosis_hosp_patid
    ON hes_diagnosis_hosp (patid);
CREATE INDEX IF NOT EXISTS idx_hes_diagnosis_hosp_icd_date
    ON hes_diagnosis_hosp (ICD, admidate);

CREATE INDEX IF NOT EXISTS idx_hes_primary_diag_hosp_patid
    ON hes_primary_diag_hosp (patid);
CREATE INDEX IF NOT EXISTS idx_hes_primary_diag_hosp_icd_date
    ON hes_primary_diag_hosp (ICD_PRIMARY, admidate);

-- ============================================================
-- Example calls
-- ============================================================

-- Extract by patient list. The source table is in the current HES database;
-- candidate_patids and cohort_hes_diagnosis_epi are in aurum_oxcprd_001b.
--
-- CALL extract_by_patid_to_table(
--     'hes_diagnosis_epi',
--     'aurum_oxcprd_001b',
--     'candidate_patids',
--     '*',
--     'cohort_hes_diagnosis_epi',
--     TRUE
-- );

-- Extract exact ICD-10 matches with inclusive date filtering.
--
-- CALL extract_by_code_to_table(
--     'hes_diagnosis_epi',
--     'aurum_oxcprd_001b',
--     'v0_alcohol_codes_icd10',
--     '2020-01-01',
--     '2024-12-31',
--     'patid, epistart, ICD',
--     'selected_hes_diagnosis_epi',
--     TRUE
-- );

-- Extract outpatient clinical diagnoses from the materialized table.
--
-- CALL extract_by_code_to_table(
--     'hesop_clinical_apptdate',
--     'aurum_oxcprd_001b',
--     'v0_alcohol_codes_icd10',
--     '2020-01-01',
--     '2024-12-31',
--     'patid, attendkey, apptdate, icd, diag_order',
--     'selected_hesop_clinical',
--     TRUE
-- );
