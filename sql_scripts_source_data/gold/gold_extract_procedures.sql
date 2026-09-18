-- USE gold;

-- Logical source families are configured once. Gold currently uses combined
-- physical source tables, represented by suffix range 0..0. The same resolver
-- also supports numbered tables if a family is configured with a non-zero range.
-- Source/config/log objects remain in gold_test. ID-list and output tables
-- reside in the caller-supplied project database.
--
-- Output tables are created directly from the requested projection and rows are
-- selected with EXISTS so duplicate IDs/codes in the input table do not
-- duplicate output rows.

/* -------------------------------------------------------------------------
   1. Configuration table: one row per logical source family and extract kind
   ------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS extract_source_config (
    extract_kind ENUM('PATID', 'CODE', 'ADID') NOT NULL,
    source_family VARCHAR(64) NOT NULL,
    first_suffix INT UNSIGNED NOT NULL DEFAULT 0,
    last_suffix INT UNSIGNED NOT NULL DEFAULT 0,
    suffix_width TINYINT UNSIGNED NOT NULL DEFAULT 3,
    id_column VARCHAR(64) NOT NULL,
    date_column VARCHAR(64) NULL,

    PRIMARY KEY (extract_kind, source_family),
    CONSTRAINT chk_extract_source_suffix_range
        CHECK (first_suffix <= last_suffix),
    CONSTRAINT chk_extract_source_suffix_width
        CHECK (suffix_width BETWEEN 1 AND 6)
) ENGINE=InnoDB;

-- Migrate the prior configuration schema without dropping existing rows.
ALTER TABLE extract_source_config
    DROP COLUMN IF EXISTS expected_index;

INSERT INTO extract_source_config (
    extract_kind, source_family, first_suffix, last_suffix, suffix_width,
    id_column, date_column
)
VALUES
    ('PATID', 'clinical',     0, 0, 3, 'patid',    NULL),
    ('PATID', 'consultation', 1, 4, 3, 'patid',    NULL),
    ('PATID', 'immunisation', 0, 0, 3, 'patid',    NULL),
    ('PATID', 'patient',      0, 0, 3, 'patid',    NULL),
    ('PATID', 'referral',     0, 0, 3, 'patid',    NULL),
    ('PATID', 'test',         1, 2, 3, 'patid',    NULL),
    ('PATID', 'therapy',      1, 3, 3, 'patid',    NULL),

    ('CODE',  'clinical',     0, 0, 3, 'medcode',  'eventdate'),
    ('CODE',  'immunisation', 0, 0, 3, 'medcode',  'eventdate'),
    ('CODE',  'referral',     0, 0, 3, 'medcode',  'eventdate'),
    ('CODE',  'test',         1, 2, 3, 'medcode',  'eventdate'),
    ('CODE',  'therapy',      1, 3, 3, 'prodcode', 'eventdate'),

    ('ADID',  'additional',   0, 0, 3, 'adid',     NULL)
ON DUPLICATE KEY UPDATE
    first_suffix = VALUES(first_suffix),
    last_suffix = VALUES(last_suffix),
    suffix_width = VALUES(suffix_width),
    id_column = VALUES(id_column),
    date_column = VALUES(date_column);


/* -------------------------------------------------------------------------
   2. Extract log
   ------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS extract_log (
    extract_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    started_at DATETIME(6) NOT NULL,
    finished_at DATETIME(6) NULL,
    status ENUM('STARTED', 'COMPLETED', 'FAILED') NOT NULL,
    extract_kind ENUM('PATID', 'CODE', 'ADID') NOT NULL,
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


/* -------------------------------------------------------------------------
   3. Core extractor
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
    DECLARE v_columns TEXT;
    DECLARE v_requested_count INT UNSIGNED DEFAULT 0;
    DECLARE v_matched_count INT UNSIGNED DEFAULT 0;
    DECLARE v_insert_cols LONGTEXT;
    DECLARE v_select_cols LONGTEXT;
    DECLARE v_sql LONGTEXT;
    DECLARE v_rows_created BIGINT UNSIGNED DEFAULT 0;
    DECLARE v_rows_this_table BIGINT DEFAULT 0;
    DECLARE v_error_message TEXT;
    DECLARE v_output_object_type VARCHAR(64) DEFAULT NULL;
    DECLARE v_old_group_concat_max_len BIGINT UNSIGNED DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        IF v_extract_id IS NOT NULL THEN
            UPDATE extract_log
            SET finished_at = NOW(6),
                status = 'FAILED',
                error_message = v_error_message
            WHERE extract_id = v_extract_id;
        END IF;

        IF v_old_group_concat_max_len IS NOT NULL THEN
            SET SESSION group_concat_max_len = v_old_group_concat_max_len;
        END IF;

        RESIGNAL;
    END;

    SET v_old_group_concat_max_len = @@SESSION.group_concat_max_len;
    SET SESSION group_concat_max_len =
        GREATEST(@@SESSION.group_concat_max_len, 1048576);

    /* Validate simple identifiers. */
    IF p_extract_kind NOT IN ('PATID', 'CODE', 'ADID') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_extract_kind must be PATID, CODE, or ADID';
    END IF;


    IF p_output_table = p_id_table THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'p_output_table must differ from p_id_table';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.schemata
        WHERE schema_name = p_output_database
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
               'p_output_database does not exist; create it before extraction';
    END IF;

    SELECT COUNT(*) INTO v_config_count
    FROM extract_source_config
    WHERE extract_kind = p_extract_kind
      AND source_family = p_source_family;
    IF v_config_count <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Unsupported extract_kind/source_family combination';
    END IF;

    SELECT
        first_suffix,
        last_suffix,
        suffix_width,
        id_column,
        date_column
    INTO
     v_first_suffix,
     v_last_suffix,
     v_suffix_width,
     v_id_col, 
     v_date_col
    FROM extract_source_config
    WHERE extract_kind = p_extract_kind
      AND source_family = p_source_family;

    IF p_extract_kind IN ('PATID', 'ADID')
       AND (p_date_from IS NOT NULL OR p_date_to IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'PATID and ADID extraction are not date-filtered; date parameters must be NULL';
    END IF;
    IF p_extract_kind = 'CODE' THEN
        IF p_date_from IS NULL OR p_date_to IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'CODE extraction requires both dates';
        END IF;
        IF p_date_from > p_date_to THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'p_date_from must not exceed p_date_to';
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
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_id_table does not exist in p_output_database';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = p_output_database
          AND table_name = p_id_table
          AND column_name = v_id_col
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_id_table does not contain the configured id column';
    END IF;

    SET v_first_source_table = CASE
        WHEN v_first_suffix = 0 AND v_last_suffix = 0
            THEN p_source_family
        ELSE CONCAT(
            p_source_family,
            '_',
            LPAD(v_first_suffix, v_suffix_width, '0')
        )
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = v_first_source_table
          AND table_type = 'BASE TABLE'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'First configured source table does not exist';
    END IF;

    /* Validate and quote the requested source columns. */
    SET v_columns = REPLACE(
        REPLACE(
            REPLACE(
                REPLACE(TRIM(COALESCE(p_columns, '*')), ' ', ''),
                CHAR(9),
                ''
            ),
            CHAR(10),
            ''
        ),
        CHAR(13),
        ''
    );

    IF v_columns = '' THEN
        SET v_columns = '*';
    END IF;

    IF v_columns <> '*'
       AND v_columns
           NOT REGEXP '^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'p_columns must be *, NULL, or simple comma-separated names';
    END IF;

    IF v_columns = '*' THEN
        SELECT
            GROUP_CONCAT(
                CONCAT('`', REPLACE(column_name, '`', '``'), '`')
                ORDER BY ordinal_position
                SEPARATOR ', '
            ),
            GROUP_CONCAT(
                CONCAT('t.`', REPLACE(column_name, '`', '``'), '`')
                ORDER BY ordinal_position
                SEPARATOR ', '
            )
        INTO v_insert_cols, v_select_cols
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = v_first_source_table;
    ELSE
        SET v_requested_count =
            1 + LENGTH(v_columns)
              - LENGTH(REPLACE(v_columns, ',', ''));

        SELECT COUNT(*)
        INTO v_matched_count
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = v_first_source_table
          AND FIND_IN_SET(column_name, v_columns) > 0;

        IF v_matched_count <> v_requested_count THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'One or more requested columns are invalid or duplicated';
        END IF;

        SELECT
            GROUP_CONCAT(CONCAT('`', REPLACE(column_name, '`', '``'), '`')
                         ORDER BY FIND_IN_SET(column_name, v_columns) SEPARATOR ', '),
            GROUP_CONCAT(CONCAT('t.`', REPLACE(column_name, '`', '``'), '`')
                         ORDER BY FIND_IN_SET(column_name, v_columns) SEPARATOR ', ')
        INTO v_insert_cols, v_select_cols
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = v_first_source_table
          AND FIND_IN_SET(column_name, v_columns) > 0;
    END IF;

    IF v_insert_cols IS NULL OR v_select_cols IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Could not resolve requested columns';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = p_output_database
          AND table_name = p_output_table
    ) THEN
        IF COALESCE(p_overwrite_output, FALSE) = FALSE THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Output table already exists; set p_overwrite_output = TRUE to replace it';
        END IF;

        SELECT table_type
        INTO v_output_object_type
        FROM information_schema.tables
        WHERE table_schema = p_output_database
          AND table_name = p_output_table
        LIMIT 1;

        SET @sql = CASE
            WHEN v_output_object_type = 'VIEW' THEN CONCAT(
                'DROP VIEW `',
                REPLACE(p_output_database, '`', '``'),
                '`.`',
                REPLACE(p_output_table, '`', '``'),
                '`'
            )
            ELSE CONCAT(
                'DROP TABLE `',
                REPLACE(p_output_database, '`', '``'),
                '`.`',
                REPLACE(p_output_table, '`', '``'),
                '`'
            )
        END;

        PREPARE stmt_drop_output FROM @sql;
        EXECUTE stmt_drop_output;
        DEALLOCATE PREPARE stmt_drop_output;
    END IF;

    INSERT INTO extract_log (
        started_at,
        status,
        extract_kind,
        source_family,
        id_table,
        output_table,
        date_from,
        date_to,
        requested_columns
    ) VALUES (
        NOW(6),
        'STARTED',
        p_extract_kind,
        p_source_family,
        CONCAT(p_output_database, '.', p_id_table),
        CONCAT(p_output_database, '.', p_output_table),
        p_date_from,
        p_date_to,
        v_columns
    );

    SET v_extract_id = LAST_INSERT_ID();

    SET @sql = CONCAT(
        'CREATE TABLE `',
        REPLACE(p_output_database, '`', '``'),
        '`.`',
        REPLACE(p_output_table, '`', '``'),
        '` ENGINE=InnoDB AS ',
        'SELECT ',
        v_select_cols,
        ' FROM `',
        REPLACE(DATABASE(), '`', '``'),
        '`.`',
        REPLACE(v_first_source_table, '`', '``'),
        '` t WHERE 1 = 0'
    );

    PREPARE stmt_create_output FROM @sql;
    EXECUTE stmt_create_output;
    DEALLOCATE PREPARE stmt_create_output;

    /* Extract each configured shard into the combined output table. */
    SET v_suffix = v_first_suffix;

    source_loop: WHILE v_suffix <= v_last_suffix DO
        SET v_source_table = CASE
            WHEN v_first_suffix = 0 AND v_last_suffix = 0
                THEN p_source_family
            ELSE CONCAT(
                p_source_family,
                '_',
                LPAD(v_suffix, v_suffix_width, '0')
            )
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_name = v_source_table
              AND table_type = 'BASE TABLE'
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'A configured source table does not exist';
        END IF;

        SET v_sql = CONCAT(
            'INSERT INTO `',
            REPLACE(p_output_database, '`', '``'),
            '`.`',
            REPLACE(p_output_table, '`', '``'),
            '` (',
            v_insert_cols,
            ') ',
            'SELECT ',
            v_select_cols,
            ' FROM `',
            REPLACE(p_output_database, '`', '``'),
            '`.`',
            REPLACE(p_id_table, '`', '``'),
            '` i ',
            'STRAIGHT_JOIN `',
            REPLACE(DATABASE(), '`', '``'),
            '`.`',
            REPLACE(v_source_table, '`', '``'),
            '` t ',
            'ON i.`',
            REPLACE(v_id_col, '`', '``'),
            '` = t.`',
            REPLACE(v_id_col, '`', '``'),
            '`'
        );

        IF p_extract_kind = 'CODE' THEN
            SET v_sql = CONCAT(
                v_sql,
                ' AND t.`',
                REPLACE(v_date_col, '`', '``'),
                '` BETWEEN ? AND ?'
            );
        END IF;

        SET @insert_sql = v_sql;
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
    SET finished_at = NOW(6),
        status = 'COMPLETED',
        rows_created = v_rows_created
    WHERE extract_id = v_extract_id;

    SET SESSION group_concat_max_len = v_old_group_concat_max_len;
END//


/* -------------------------------------------------------------------------
   5. Public wrappers
   ------------------------------------------------------------------------- */

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
        'PATID',
        p_source_family,
        p_output_database,
        p_patid_table,
        NULL,
        NULL,
        p_columns,
        p_output_table,
        p_overwrite_output
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
        'CODE',
        p_source_family,
        p_output_database,
        p_code_table,
        p_date_from,
        p_date_to,
        p_columns,
        p_output_table,
        p_overwrite_output
    );
END//

CREATE OR REPLACE PROCEDURE extract_by_adid_to_table (
    IN p_source_family VARCHAR(64),
    IN p_output_database VARCHAR(128),
    IN p_adid_table VARCHAR(128),
    IN p_columns TEXT,
    IN p_output_table VARCHAR(128),
    IN p_overwrite_output BOOLEAN
)
BEGIN
    CALL extract_to_table_core(
        'ADID', p_source_family, p_output_database, p_adid_table,
        NULL, NULL, p_columns, p_output_table, p_overwrite_output
    );
END//

DELIMITER ;


/* -------------------------------------------------------------------------
   6. Examples
   -------------------------------------------------------------------------

-- ID-list tables are stored in that project database:
-- CREATE TABLE gold_oxcprd_001b.patids (
--     patid BIGINT UNSIGNED NOT NULL,
--     PRIMARY KEY (patid)
-- ) ENGINE=InnoDB;

-- Extract all matching clinical rows:
-- CALL extract_by_patid_to_table(
--     'clinical',
--     'gold_oxcprd_001b',
--     'patids',
--     '*',
--     'clinical',
--     TRUE
-- );

-- Extract therapy rows matching product codes and dates:
-- CALL extract_by_code_to_table(
--     'therapy',
--     'gold_oxcprd_001b',
--     'selected_prodcodes',
--     '2020-01-01',
--     '2024-12-31',
--     'patid,eventdate,prodcode',
--     'selected_therapy',
--     TRUE
-- );

-- Use ADIDs from an extracted clinical table:
-- CALL extract_by_adid_to_table(
--     'additional',
--     'gold_oxcprd_001b',
--     'clinical',
--     '*',
--     'additional',
--     TRUE
-- );
*/
