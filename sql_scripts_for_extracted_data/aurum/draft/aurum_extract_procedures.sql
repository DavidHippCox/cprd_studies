USE aurum_test;

-- Logical source families are configured once. Numbered physical tables are
-- resolved as <source_family>_<zero-padded suffix> during extraction.
-- Source/config/log objects remain in aurum_test. ID-list and output tables
-- reside in the caller-supplied project database.
--

/* -------------------------------------------------------------------------
   1. Configuration table: one row per logical source family and extract kind
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS extract_source_config;

CREATE TABLE IF NOT EXISTS extract_source_config (
    extract_kind ENUM('PATID', 'CODE') NOT NULL,
    source_family VARCHAR(64) NOT NULL,
    first_suffix INT UNSIGNED NOT NULL DEFAULT 0,
    last_suffix INT UNSIGNED NOT NULL DEFAULT 0,
    suffix_width TINYINT UNSIGNED NOT NULL DEFAULT 3,
    id_column VARCHAR(64) NOT NULL,
    date_column VARCHAR(64) NULL,
    expected_index VARCHAR(128) NULL,

    PRIMARY KEY (extract_kind, source_family),
    CONSTRAINT chk_extract_source_suffix_range
        CHECK (first_suffix <= last_suffix),
    CONSTRAINT chk_extract_source_suffix_width
        CHECK (suffix_width BETWEEN 1 AND 6)
) ENGINE=InnoDB;

INSERT INTO extract_source_config (
    extract_kind, source_family, first_suffix, last_suffix, suffix_width,
    id_column, date_column, expected_index
)
VALUES
    ('PATID', 'drugissue',    1,  8, 3, 'patid',      NULL,        'idx_patid'),
    ('PATID', 'observation',  1, 20, 3, 'patid',      NULL,        'idx_patid'),
    ('PATID', 'consultation', 1,  7, 3, 'patid',      NULL,        'idx_patid'),
    ('PATID', 'referral',     0,  0, 3, 'patid',      NULL,        'idx_patid'),
    ('PATID', 'problem',      0,  0, 3, 'patid',      NULL,        'idx_patid'),
    ('PATID', 'patient',      0,  0, 3, 'patid',      NULL,        'PRIMARY'),

    ('CODE',  'drugissue',    1,  8, 3, 'prodcodeid', 'issuedate', 'idx_prodcodeid_issuedate'),
    ('CODE',  'observation',  1, 20, 3, 'medcodeid',  'obsdate',   'idx_medcodeid_obsdate')
ON DUPLICATE KEY UPDATE
    first_suffix = VALUES(first_suffix),
    last_suffix = VALUES(last_suffix),
    suffix_width = VALUES(suffix_width),
    id_column = VALUES(id_column),
    date_column = VALUES(date_column),
    expected_index = VALUES(expected_index);


/* -------------------------------------------------------------------------
   2. Extract log
   ------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS extract_log (
    extract_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    started_at DATETIME(6) NOT NULL,
    finished_at DATETIME(6) NULL,
    status ENUM('STARTED', 'COMPLETED', 'FAILED') NOT NULL,
    extract_kind ENUM('PATID', 'CODE') NOT NULL,
    source_family VARCHAR(64) NOT NULL,
    id_table VARCHAR(260) NOT NULL,
    output_table VARCHAR(260) NOT NULL,
    date_from DATE NULL,
    date_to DATE NULL,
    requested_columns TEXT NULL,
    rows_created BIGINT UNSIGNED NULL,
    error_message TEXT NULL,
    PRIMARY KEY (extract_id),
    INDEX idx_extract_log_started_at (started_at),
    INDEX idx_extract_log_status (status),
    INDEX idx_extract_log_source_family (source_family),
    INDEX idx_extract_log_output_table (output_table)
) ENGINE=InnoDB;

-- Migrate the prior log schema without discarding existing log rows.
ALTER TABLE extract_log
    CHANGE COLUMN IF EXISTS source_table source_family VARCHAR(64) NOT NULL;

/* -------------------------------------------------------------------------
   3. Helper: drop indexes copied into an output table
   ------------------------------------------------------------------------- */

DELIMITER //

CREATE OR REPLACE PROCEDURE extract_drop_all_indexes (
    IN p_output_database VARCHAR(128),
    IN p_table_name VARCHAR(128)
)
BEGIN
    DECLARE v_sql LONGTEXT;

    IF p_output_database IS NULL
       OR p_output_database NOT REGEXP '^aurum_oxcprd_[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_output_database must match aurum_oxcprd_<project_code>';
    END IF;

    IF p_table_name IS NULL
       OR p_table_name NOT REGEXP '^[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_table_name must be a simple table name';
    END IF;

    SELECT GROUP_CONCAT(
        DISTINCT CASE
            WHEN index_name = 'PRIMARY' THEN 'DROP PRIMARY KEY'
            ELSE CONCAT('DROP INDEX `', REPLACE(index_name, '`', '``'), '`')
        END
        SEPARATOR ', '
    )
    INTO v_sql
    FROM information_schema.statistics
    WHERE table_schema = p_output_database
      AND table_name = p_table_name;

    IF v_sql IS NOT NULL AND v_sql <> '' THEN
        SET @sql = CONCAT(
            'ALTER TABLE `', REPLACE(p_output_database, '`', '``'), '`.`',
            REPLACE(p_table_name, '`', '``'), '` ', v_sql
        );
        PREPARE stmt_drop_indexes FROM @sql;
        EXECUTE stmt_drop_indexes;
        DEALLOCATE PREPARE stmt_drop_indexes;
    END IF;
END//

DELIMITER ;


/* -------------------------------------------------------------------------
   4. Helper: drop unrequested columns from an output table
   ------------------------------------------------------------------------- */

DELIMITER //

CREATE OR REPLACE PROCEDURE extract_drop_unwanted_columns (
    IN p_output_database VARCHAR(128),
    IN p_output_table VARCHAR(128),
    IN p_requested_columns TEXT
)
BEGIN
    DECLARE v_requested_cols TEXT;
    DECLARE v_requested_count INT DEFAULT 0;
    DECLARE v_matched_count INT DEFAULT 0;
    DECLARE v_sql LONGTEXT;

    IF p_output_database IS NULL
       OR p_output_database NOT REGEXP '^aurum_oxcprd_[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_output_database must match aurum_oxcprd_<project_code>';
    END IF;

    IF p_output_table IS NULL
       OR p_output_table NOT REGEXP '^[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_output_table must be a simple table name';
    END IF;

    SET v_requested_cols = REPLACE(REPLACE(REPLACE(
        TRIM(COALESCE(p_requested_columns, '*')), ' ', ''), '\n', ''), '\r', '');
    IF v_requested_cols = '' THEN SET v_requested_cols = '*'; END IF;

    IF v_requested_cols <> '*' THEN
        IF v_requested_cols REGEXP '(^,|,,|,$)'
           OR v_requested_cols NOT REGEXP '^[A-Za-z0-9_,]+$' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'p_requested_columns must be NULL, *, or a comma-separated list of simple column names';
        END IF;

        SET v_requested_count =
            1 + LENGTH(v_requested_cols) - LENGTH(REPLACE(v_requested_cols, ',', ''));

        SELECT COUNT(*)
        INTO v_matched_count
        FROM information_schema.columns
        WHERE table_schema = p_output_database
          AND table_name = p_output_table
          AND FIND_IN_SET(column_name, v_requested_cols);

        IF v_matched_count <> v_requested_count THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'One or more requested columns are invalid or duplicated';
        END IF;

        SELECT GROUP_CONCAT(
            CONCAT('DROP COLUMN `', REPLACE(column_name, '`', '``'), '`')
            ORDER BY ordinal_position DESC SEPARATOR ', '
        )
        INTO v_sql
        FROM information_schema.columns
        WHERE table_schema = p_output_database
          AND table_name = p_output_table
          AND FIND_IN_SET(column_name, v_requested_cols) = 0;
    END IF;

    IF v_sql IS NOT NULL AND v_sql <> '' THEN
        SET @sql = CONCAT(
            'ALTER TABLE `', REPLACE(p_output_database, '`', '``'), '`.`',
            REPLACE(p_output_table, '`', '``'), '` ', v_sql
        );
        PREPARE stmt_drop_columns FROM @sql;
        EXECUTE stmt_drop_columns;
        DEALLOCATE PREPARE stmt_drop_columns;
    END IF;
END//

DELIMITER ;


/* -------------------------------------------------------------------------
   5. Helper: create the combined output table from the first physical source
   ------------------------------------------------------------------------- */

DELIMITER //

CREATE OR REPLACE PROCEDURE extract_prepare_output_table (
    IN p_source_table VARCHAR(128),
    IN p_output_database VARCHAR(128),
    IN p_output_table VARCHAR(128),
    IN p_requested_columns TEXT,
    IN p_overwrite_output BOOLEAN
)
BEGIN
    IF p_source_table IS NULL
       OR p_source_table NOT REGEXP '^[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_source_table must be a simple table name';
    END IF;

    IF p_output_database IS NULL
       OR p_output_database NOT REGEXP '^aurum_oxcprd_[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_output_database must match aurum_oxcprd_<project_code>';
    END IF;

    IF p_output_table IS NULL
       OR p_output_table NOT REGEXP '^[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_output_table must be a simple table name';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = p_output_database
          AND table_name = p_output_table
    ) AND COALESCE(p_overwrite_output, FALSE) = FALSE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Output table already exists; set p_overwrite_output = TRUE to replace it';
    END IF;

    IF COALESCE(p_overwrite_output, FALSE) = TRUE THEN
        SET @sql = CONCAT(
            'DROP TABLE IF EXISTS `', REPLACE(p_output_database, '`', '``'), '`.`',
            REPLACE(p_output_table, '`', '``'), '`'
        );
        PREPARE stmt_drop_output FROM @sql;
        EXECUTE stmt_drop_output;
        DEALLOCATE PREPARE stmt_drop_output;
    END IF;

    SET @sql = CONCAT(
        'CREATE TABLE `', REPLACE(p_output_database, '`', '``'), '`.`',
        REPLACE(p_output_table, '`', '``'), '` LIKE `',
        REPLACE(DATABASE(), '`', '``'), '`.`', REPLACE(p_source_table, '`', '``'), '`'
    );
    PREPARE stmt_create_output FROM @sql;
    EXECUTE stmt_create_output;
    DEALLOCATE PREPARE stmt_create_output;

    CALL extract_drop_all_indexes(p_output_database, p_output_table);
    CALL extract_drop_unwanted_columns(
        p_output_database, p_output_table, p_requested_columns
    );
END//

DELIMITER ;


/* -------------------------------------------------------------------------
   6. Helper: resolve final output column lists
   ------------------------------------------------------------------------- */

DELIMITER //

CREATE OR REPLACE PROCEDURE extract_get_output_columns (
    IN p_output_database VARCHAR(128),
    IN p_output_table VARCHAR(128),
    OUT p_insert_columns LONGTEXT,
    OUT p_select_columns LONGTEXT
)
BEGIN
    SELECT
        GROUP_CONCAT(CONCAT('`', REPLACE(column_name, '`', '``'), '`')
                     ORDER BY ordinal_position SEPARATOR ', '),
        GROUP_CONCAT(CONCAT('t.`', REPLACE(column_name, '`', '``'), '`')
                     ORDER BY ordinal_position SEPARATOR ', ')
    INTO p_insert_columns, p_select_columns
    FROM information_schema.columns
    WHERE table_schema = p_output_database
      AND table_name = p_output_table;

    IF p_insert_columns IS NULL OR p_select_columns IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Could not resolve output columns';
    END IF;
END//

DELIMITER ;


/* -------------------------------------------------------------------------
   7. Core procedure: loop through all configured physical source tables
   ------------------------------------------------------------------------- */

DELIMITER //

CREATE OR REPLACE PROCEDURE extract_to_table_core (
    IN p_extract_kind VARCHAR(10),
    IN p_source_family VARCHAR(64),
    IN p_output_database VARCHAR(128),
    IN p_id_table VARCHAR(128),
    IN p_date_from DATE,
    IN p_date_to DATE,
    IN p_columns TEXT,
    IN p_output_table VARCHAR(128),
    IN p_overwrite_output BOOLEAN
)
BEGIN
    DECLARE v_extract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_config_count INT DEFAULT 0;
    DECLARE v_first_suffix INT UNSIGNED;
    DECLARE v_last_suffix INT UNSIGNED;
    DECLARE v_suffix_width TINYINT UNSIGNED;
    DECLARE v_id_col VARCHAR(64);
    DECLARE v_date_col VARCHAR(64);
    DECLARE v_suffix INT UNSIGNED;
    DECLARE v_source_table VARCHAR(128);
    DECLARE v_first_source_table VARCHAR(128);
    DECLARE v_insert_cols LONGTEXT;
    DECLARE v_select_cols LONGTEXT;
    DECLARE v_insert_sql LONGTEXT;
    DECLARE v_rows_created BIGINT UNSIGNED DEFAULT 0;
    DECLARE v_rows_this_table BIGINT DEFAULT 0;
    DECLARE v_error_message TEXT;
    DECLARE v_old_group_concat_max_len BIGINT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_message = MESSAGE_TEXT;
        IF v_extract_id IS NOT NULL THEN
            UPDATE extract_log
            SET finished_at = NOW(6), status = 'FAILED', error_message = v_error_message
            WHERE extract_id = v_extract_id;
        END IF;
        IF v_old_group_concat_max_len IS NOT NULL THEN
            SET SESSION group_concat_max_len = v_old_group_concat_max_len;
        END IF;
        RESIGNAL;
    END;

    SET v_old_group_concat_max_len = @@SESSION.group_concat_max_len;
    SET SESSION group_concat_max_len = GREATEST(@@SESSION.group_concat_max_len, 1048576);

    IF p_extract_kind NOT IN ('PATID', 'CODE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_extract_kind must be PATID or CODE';
    END IF;
    IF p_source_family IS NULL
       OR p_source_family NOT REGEXP '^[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_source_family must be a simple family name';
    END IF;
    IF p_output_database IS NULL
       OR p_output_database NOT REGEXP '^aurum_oxcprd_[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_output_database must match aurum_oxcprd_<project_code>';
    END IF;
    IF p_id_table IS NULL OR p_id_table NOT REGEXP '^[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_id_table must be a simple table name';
    END IF;
    IF p_output_table IS NULL OR p_output_table NOT REGEXP '^[A-Za-z0-9_]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_output_table must be a simple table name';
    END IF;
    IF p_output_table = p_id_table THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_output_table must differ from p_id_table';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = p_output_database
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_output_database does not exist; create it before extraction';
    END IF;

    SELECT COUNT(*) INTO v_config_count
    FROM extract_source_config
    WHERE extract_kind = p_extract_kind
      AND source_family = p_source_family;
    IF v_config_count <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Unsupported extract_kind/source_family combination';
    END IF;

    SELECT first_suffix, last_suffix, suffix_width, id_column, date_column
    INTO v_first_suffix, v_last_suffix, v_suffix_width, v_id_col, v_date_col
    FROM extract_source_config
    WHERE extract_kind = p_extract_kind
      AND source_family = p_source_family;

    IF p_extract_kind = 'PATID'
       AND (p_date_from IS NOT NULL OR p_date_to IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'PATID extraction is not date-filtered; date parameters must be NULL';
    END IF;
    IF p_extract_kind = 'CODE' THEN
        IF p_date_from IS NULL OR p_date_to IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'CODE extraction requires p_date_from and p_date_to';
        END IF;
        IF p_date_from > p_date_to THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'p_date_from must be less than or equal to p_date_to';
        END IF;
        IF v_date_col IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'CODE extraction requires a configured date_column';
        END IF;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = p_output_database
          AND table_name = p_id_table
          AND table_type = 'BASE TABLE'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_id_table does not exist as a base table in p_output_database';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = p_output_database
          AND table_name = p_id_table
          AND column_name = v_id_col
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_id_table does not contain the configured id column';
    END IF;

    SET v_first_source_table = CASE
        WHEN v_first_suffix = 0 AND v_last_suffix = 0 THEN p_source_family
        ELSE CONCAT(p_source_family, '_', LPAD(v_first_suffix, v_suffix_width, '0'))
    END;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = v_first_source_table
          AND table_type = 'BASE TABLE'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'First configured physical source table does not exist in the current database';
    END IF;

    INSERT INTO extract_log (
        started_at, status, extract_kind, source_family, id_table, output_table,
        date_from, date_to, requested_columns
    ) VALUES (
        NOW(6), 'STARTED', p_extract_kind, p_source_family,
        CONCAT(p_output_database, '.', p_id_table),
        CONCAT(p_output_database, '.', p_output_table),
        p_date_from, p_date_to, p_columns
    );
    SET v_extract_id = LAST_INSERT_ID();

    CALL extract_prepare_output_table(
        v_first_source_table, p_output_database, p_output_table,
        p_columns, p_overwrite_output
    );
    CALL extract_get_output_columns(
        p_output_database, p_output_table, v_insert_cols, v_select_cols
    );

    SET v_suffix = v_first_suffix;
    source_loop: WHILE v_suffix <= v_last_suffix DO
        SET v_source_table = CASE
            WHEN v_first_suffix = 0 AND v_last_suffix = 0 THEN p_source_family
            ELSE CONCAT(p_source_family, '_', LPAD(v_suffix, v_suffix_width, '0'))
        END;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_name = v_source_table
              AND table_type = 'BASE TABLE'
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A configured physical source table does not exist in the current database';
        END IF;

        SET v_insert_sql = CONCAT(
            'INSERT INTO `', REPLACE(p_output_database, '`', '``'), '`.`',
            REPLACE(p_output_table, '`', '``'), '` (', v_insert_cols, ') ',
            'SELECT ', v_select_cols, ' ',
            'FROM `', REPLACE(p_output_database, '`', '``'), '`.`',
            REPLACE(p_id_table, '`', '``'), '` i ',
            'JOIN `', REPLACE(DATABASE(), '`', '``'), '`.`',
            REPLACE(v_source_table, '`', '``'), '` t ',
            'ON t.`', REPLACE(v_id_col, '`', '``'), '` = i.`',
            REPLACE(v_id_col, '`', '``'), '`'
        );

        IF p_extract_kind = 'CODE' THEN
            SET v_insert_sql = CONCAT(
                v_insert_sql, ' WHERE t.`', REPLACE(v_date_col, '`', '``'),
                '` BETWEEN ? AND ?'
            );
        END IF;

        SET @insert_sql = v_insert_sql;
        SET @date_from = p_date_from;
        SET @date_to = p_date_to;
        PREPARE stmt_insert_rows FROM @insert_sql;
        IF p_extract_kind = 'CODE' THEN
            EXECUTE stmt_insert_rows USING @date_from, @date_to;
        ELSE
            EXECUTE stmt_insert_rows;
        END IF;
        SET v_rows_this_table = ROW_COUNT();
        SET v_rows_created = v_rows_created + v_rows_this_table;
        DEALLOCATE PREPARE stmt_insert_rows;

        IF v_first_suffix = 0 AND v_last_suffix = 0 THEN
            LEAVE source_loop;
        END IF;
        SET v_suffix = v_suffix + 1;
    END WHILE;

    UPDATE extract_log
    SET finished_at = NOW(6), status = 'COMPLETED', rows_created = v_rows_created
    WHERE extract_id = v_extract_id;

    SET SESSION group_concat_max_len = v_old_group_concat_max_len;
END//

DELIMITER ;


/* -------------------------------------------------------------------------
   8. Public wrappers
   ------------------------------------------------------------------------- */

DELIMITER //

CREATE OR REPLACE PROCEDURE extract_by_patid_to_table (
    IN p_source_family VARCHAR(64),
    IN p_output_database VARCHAR(128),
    IN p_patid_table VARCHAR(128),
    IN p_columns TEXT,
    IN p_output_table VARCHAR(128),
    IN p_overwrite_output BOOLEAN
)
BEGIN
    CALL extract_to_table_core(
        'PATID', p_source_family, p_output_database, p_patid_table,
        NULL, NULL, p_columns, p_output_table, p_overwrite_output
    );
END//

CREATE OR REPLACE PROCEDURE extract_by_code_to_table (
    IN p_source_family VARCHAR(64),
    IN p_output_database VARCHAR(128),
    IN p_code_table VARCHAR(128),
    IN p_date_from DATE,
    IN p_date_to DATE,
    IN p_columns TEXT,
    IN p_output_table VARCHAR(128),
    IN p_overwrite_output BOOLEAN
)
BEGIN
    CALL extract_to_table_core(
        'CODE', p_source_family, p_output_database, p_code_table,
        p_date_from, p_date_to, p_columns, p_output_table, p_overwrite_output
    );
END//

DELIMITER ;


/* -------------------------------------------------------------------------
   9. Examples
   -------------------------------------------------------------------------

-- The project database must already exist:
-- CREATE DATABASE aurum_oxcprd_001b;

-- ID-list tables are stored in that project database:
-- CREATE TABLE aurum_oxcprd_001b.candidate_patids (
--     patid BIGINT UNSIGNED NOT NULL,
--     PRIMARY KEY (patid)
-- ) ENGINE=InnoDB;

-- All observation_001 ... observation_020 rows matching the PATID list are
-- appended to one combined output table:
-- CALL extract_by_patid_to_table(
--     'observation',
--     'aurum_oxcprd_001b',
--     'candidate_patids',
--     '*',
--     'cohort_observation',
--     TRUE
-- );

-- All drugissue_001 ... drugissue_008 rows matching products and dates:
-- CALL extract_by_code_to_table(
--     'drugissue',
--     'aurum_oxcprd_001b',
--     'v0_dementia_drug_aurum',
--     '2020-01-01',
--     '2024-12-31',
--     'patid,issuedate,prodcodeid',
--     'selected_drugissue',
--     TRUE
-- );

-- All observation_001 ... observation_008 rows matching products and dates:
-- CALL extract_by_code_to_table(
--     'observation',
--     'aurum_oxcprd_001b',
--     'v0_alcohol_codes_aurum',
--     '2020-01-01',
--     '2024-12-31',
--     'patid,obsdate,medcodeid',
--     'selected_observation',
--     TRUE
-- );

-- All consultation_001 ... consultation_007 rows matching the PATID list:
-- CALL extract_by_patid_to_table(
--     'consultation',
--     'aurum_oxcprd_001b',
--     'candidate_patids',
--     '*',
--     'cohort_consultation',
--     TRUE
-- );
*/
