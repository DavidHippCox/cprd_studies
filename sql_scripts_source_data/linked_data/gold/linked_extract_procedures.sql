/*

--  Some of the schema is from 
--  https://github.com/Exeter-Diabetes/CPRD-analysis-package/blob/646c32a216c6f43d1b3135b86cd99cb1ef5eb219/data-raw/data-tables.yaml: 

  Linked-data extraction procedures for MariaDB 12.3.2.

  Run this script while the database containing the linked source tables is
  selected. Input patid/codelist tables and output tables are held in
  p_output_database.

  Input-list contract:
  - PATID extracts require a column named patid.
  - CODE extracts require a column named icd10.
  - Duplicate non-NULL IDs stop the extraction before the output is changed.
*/

/* -------------------------------------------------------------------------
   1. Source-table configuration
   ------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS linked_extract_source_config (
    source_table VARCHAR(64) NOT NULL,
    patid_column VARCHAR(64) NOT NULL DEFAULT 'patid',
    code_column VARCHAR(64) NULL,
    date_column VARCHAR(64) NULL,

    PRIMARY KEY (source_table),
    CONSTRAINT chk_linked_extract_code_date
        CHECK (
            (code_column IS NULL AND date_column IS NULL)
            OR
            (code_column IS NOT NULL AND date_column IS NOT NULL)
        )
) ENGINE=InnoDB;

INSERT INTO linked_extract_source_config (
    source_table,
    patid_column,
    code_column,
    date_column
)
VALUES
    ('hesae_patient',          'patid', NULL,          NULL),
    ('hesae_attendance',       'patid', NULL,          NULL),
    ('hesae_diagnosis',        'patid', NULL,          NULL),
    ('hesae_investigation',    'patid', NULL,          NULL),
    ('hesae_treatment',        'patid', NULL,          NULL),
    ('hesae_hrg',              'patid', NULL,          NULL),
    ('hesae_pathway',          'patid', NULL,          NULL),
    ('hes_patient',            'patid', NULL,          NULL),
    ('hes_maternity',          'patid', NULL,          NULL),
    ('hes_hospital',           'patid', NULL,          NULL),
    ('hes_episodes',           'patid', NULL,          NULL),
    ('hes_diagnosis_epi',      'patid', 'ICD',         'epistart'),
    ('hes_diagnosis_hosp',     'patid', 'ICD',         'admidate'),
    ('hes_hrg',                'patid', NULL,          NULL),
    ('hes_primary_diag_hosp',  'patid', 'ICD_PRIMARY', 'admidate'),
    ('hes_procedures_epi',     'patid', NULL,          NULL),
    ('hes_ccare',              'patid', NULL,          NULL),
    ('hesop_patient',          'patid', NULL,          NULL),
    ('hesop_patient_pathway',  'patid', NULL,          NULL),
    ('hesop_appointment',      'patid', NULL,          NULL),
    ('hesop_clinical_apptdate','patid', 'icd',         'apptdate'),
    ('hesop_clinical',         'patid', NULL,          NULL),
    ('hesop_operation',        'patid', NULL,          NULL),
    ('linkage_eligibility',    'patid', NULL,          NULL),
    ('ethnicity_record',       'patid', NULL,          NULL),
    ('patient_2019_imd',       'patid', NULL,          NULL),
    ('death_patient',          'patid', NULL,          NULL)
ON DUPLICATE KEY UPDATE
    patid_column = VALUES(patid_column),
    code_column = VALUES(code_column),
    date_column = VALUES(date_column);

/* -------------------------------------------------------------------------
   2. Extract log
   ------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS linked_extract_log (
    extract_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    started_at DATETIME(6) NOT NULL,
    finished_at DATETIME(6) NULL,
    status ENUM('STARTED', 'COMPLETED', 'FAILED') NOT NULL,
    extract_kind ENUM('PATID', 'CODE') NOT NULL,
    source_table VARCHAR(64) NOT NULL,
    id_table VARCHAR(260) NOT NULL,
    output_table VARCHAR(260) NOT NULL,
    date_from DATE NULL,
    date_to DATE NULL,
    requested_columns TEXT NULL,
    overwrite_output BOOLEAN NOT NULL DEFAULT FALSE,
    rows_created BIGINT UNSIGNED NULL,
    error_message TEXT NULL,

    PRIMARY KEY (extract_id),
    INDEX idx_linked_extract_log_started (started_at),
    INDEX idx_linked_extract_log_status (status),
    INDEX idx_linked_extract_log_source (source_table),
    INDEX idx_linked_extract_log_output (output_table)
) ENGINE=InnoDB;

/* -------------------------------------------------------------------------
   3. Core extractor
   ------------------------------------------------------------------------- */

DELIMITER //

CREATE OR REPLACE PROCEDURE extract_linked_to_table_core (
    IN p_extract_kind VARCHAR(10),
    IN p_source_table VARCHAR(64),
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
    DECLARE v_input_id_column VARCHAR(64);
    DECLARE v_source_id_column VARCHAR(64);
    DECLARE v_patid_column VARCHAR(64);
    DECLARE v_code_column VARCHAR(64);
    DECLARE v_date_column VARCHAR(64);
    DECLARE v_columns TEXT;
    DECLARE v_requested_count INT UNSIGNED DEFAULT 0;
    DECLARE v_matched_count INT UNSIGNED DEFAULT 0;
    DECLARE v_insert_columns LONGTEXT;
    DECLARE v_select_columns LONGTEXT;
    DECLARE v_sql LONGTEXT;
    DECLARE v_rows_created BIGINT UNSIGNED DEFAULT 0;
    DECLARE v_error_message TEXT;
    DECLARE v_output_object_type VARCHAR(64) DEFAULT NULL;
    DECLARE v_old_group_concat_max_len BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_has_duplicate_ids BOOLEAN DEFAULT FALSE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        IF v_extract_id IS NOT NULL THEN
            UPDATE linked_extract_log
            SET finished_at = NOW(6),
                status = 'FAILED',
                error_message = v_error_message
            WHERE extract_id = v_extract_id;
        END IF;

        IF v_old_group_concat_max_len IS NOT NULL THEN
            SET SESSION group_concat_max_len =
                v_old_group_concat_max_len;
        END IF;

        RESIGNAL;
    END;

    SET v_old_group_concat_max_len = @@SESSION.group_concat_max_len;
    SET SESSION group_concat_max_len =
        GREATEST(@@SESSION.group_concat_max_len, 1048576);

    IF p_extract_kind NOT IN ('PATID', 'CODE') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'p_extract_kind must be PATID or CODE';
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
                'p_output_database does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM linked_extract_source_config
        WHERE source_table = p_source_table
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Unsupported linked source table';
    END IF;

    SELECT
        patid_column,
        code_column,
        date_column
    INTO
        v_patid_column,
        v_code_column,
        v_date_column
    FROM linked_extract_source_config
    WHERE source_table = p_source_table;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = p_source_table
          AND table_type = 'BASE TABLE'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Configured linked source table does not exist';
    END IF;

    IF p_extract_kind = 'PATID' THEN
        IF p_date_from IS NOT NULL OR p_date_to IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'PATID extraction does not accept date filters';
        END IF;

        SET v_input_id_column = 'patid';
        SET v_source_id_column = v_patid_column;
    ELSE
        IF v_code_column IS NULL OR v_date_column IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'Source table is not configured for CODE extraction';
        END IF;

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

        SET v_input_id_column = 'icd10';
        SET v_source_id_column = v_code_column;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = p_output_database
          AND table_name = p_id_table
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Input ID table or view does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = p_output_database
          AND table_name = p_id_table
          AND column_name = v_input_id_column
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Input list lacks the required patid or icd10 column';
    END IF;

    /* Validate duplicates before dropping or creating an output object. */
    SET @has_duplicate_ids = FALSE;
    SET @duplicate_check_sql = CONCAT(
        'SELECT EXISTS (',
        'SELECT 1 FROM `',
        REPLACE(p_output_database, '`', '``'),
        '`.`',
        REPLACE(p_id_table, '`', '``'),
        '` WHERE `',
        REPLACE(v_input_id_column, '`', '``'),
        '` IS NOT NULL GROUP BY `',
        REPLACE(v_input_id_column, '`', '``'),
        '` HAVING COUNT(*) > 1 LIMIT 1',
        ') INTO @has_duplicate_ids'
    );

    PREPARE stmt_duplicate_check FROM @duplicate_check_sql;
    EXECUTE stmt_duplicate_check;
    DEALLOCATE PREPARE stmt_duplicate_check;

    SET v_has_duplicate_ids = COALESCE(@has_duplicate_ids, FALSE);

    IF v_has_duplicate_ids THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Input patid or icd10 list contains duplicates; extraction stopped';
    END IF;

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
        INTO v_insert_columns, v_select_columns
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = p_source_table;
    ELSE
        SET v_requested_count =
            1 + LENGTH(v_columns)
              - LENGTH(REPLACE(v_columns, ',', ''));

        SELECT COUNT(*)
        INTO v_matched_count
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = p_source_table
          AND FIND_IN_SET(column_name, v_columns) > 0;

        IF v_matched_count <> v_requested_count THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'One or more requested columns are invalid or duplicated';
        END IF;

        SELECT
            GROUP_CONCAT(
                CONCAT('`', REPLACE(column_name, '`', '``'), '`')
                ORDER BY FIND_IN_SET(column_name, v_columns)
                SEPARATOR ', '
            ),
            GROUP_CONCAT(
                CONCAT('t.`', REPLACE(column_name, '`', '``'), '`')
                ORDER BY FIND_IN_SET(column_name, v_columns)
                SEPARATOR ', '
            )
        INTO v_insert_columns, v_select_columns
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = p_source_table
          AND FIND_IN_SET(column_name, v_columns) > 0;
    END IF;

    IF v_insert_columns IS NULL OR v_select_columns IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Could not resolve requested columns';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = p_output_database
          AND table_name = p_output_table
    ) THEN
        IF COALESCE(p_overwrite_output, FALSE) = FALSE THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT =
                    'Output exists; set overwrite to TRUE to replace it';
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

    INSERT INTO linked_extract_log (
        started_at,
        status,
        extract_kind,
        source_table,
        id_table,
        output_table,
        date_from,
        date_to,
        requested_columns,
        overwrite_output
    ) VALUES (
        NOW(6),
        'STARTED',
        p_extract_kind,
        p_source_table,
        CONCAT(p_output_database, '.', p_id_table),
        CONCAT(p_output_database, '.', p_output_table),
        p_date_from,
        p_date_to,
        v_columns,
        COALESCE(p_overwrite_output, FALSE)
    );

    SET v_extract_id = LAST_INSERT_ID();

    SET @sql = CONCAT(
        'CREATE TABLE `',
        REPLACE(p_output_database, '`', '``'),
        '`.`',
        REPLACE(p_output_table, '`', '``'),
        '` ENGINE=InnoDB AS SELECT ',
        v_select_columns,
        ' FROM `',
        REPLACE(DATABASE(), '`', '``'),
        '`.`',
        REPLACE(p_source_table, '`', '``'),
        '` t WHERE 1 = 0'
    );

    PREPARE stmt_create_output FROM @sql;
    EXECUTE stmt_create_output;
    DEALLOCATE PREPARE stmt_create_output;

    SET v_sql = CONCAT(
        'INSERT INTO `',
        REPLACE(p_output_database, '`', '``'),
        '`.`',
        REPLACE(p_output_table, '`', '``'),
        '` (',
        v_insert_columns,
        ') SELECT ',
        v_select_columns,
        ' FROM `',
        REPLACE(p_output_database, '`', '``'),
        '`.`',
        REPLACE(p_id_table, '`', '``'),
        '` i STRAIGHT_JOIN `',
        REPLACE(DATABASE(), '`', '``'),
        '`.`',
        REPLACE(p_source_table, '`', '``'),
        '` t ON i.`',
        REPLACE(v_input_id_column, '`', '``'),
        '` = t.`',
        REPLACE(v_source_id_column, '`', '``'),
        '`'
    );

    IF p_extract_kind = 'CODE' THEN
        SET v_sql = CONCAT(
            v_sql,
            ' AND t.`',
            REPLACE(v_date_column, '`', '``'),
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

    SET v_rows_created = ROW_COUNT();
    DEALLOCATE PREPARE stmt_insert_rows;

    UPDATE linked_extract_log
    SET finished_at = NOW(6),
        status = 'COMPLETED',
        rows_created = v_rows_created
    WHERE extract_id = v_extract_id;

    SET SESSION group_concat_max_len = v_old_group_concat_max_len;
END//

/* -------------------------------------------------------------------------
   4. Public wrappers
   ------------------------------------------------------------------------- */

CREATE OR REPLACE PROCEDURE extract_linked_by_patid_to_table (
    IN p_source_table VARCHAR(64),
    IN p_output_database VARCHAR(128),
    IN p_patid_table VARCHAR(128),
    IN p_columns TEXT,
    IN p_output_table VARCHAR(128),
    IN p_overwrite_output BOOLEAN
)
BEGIN
    CALL extract_linked_to_table_core(
        'PATID',
        p_source_table,
        p_output_database,
        p_patid_table,
        NULL,
        NULL,
        p_columns,
        p_output_table,
        p_overwrite_output
    );
END//

CREATE OR REPLACE PROCEDURE extract_linked_by_code_to_table (
    IN p_source_table VARCHAR(64),
    IN p_output_database VARCHAR(128),
    IN p_codelist_table VARCHAR(128),
    IN p_date_from DATE,
    IN p_date_to DATE,
    IN p_columns TEXT,
    IN p_output_table VARCHAR(128),
    IN p_overwrite_output BOOLEAN
)
BEGIN
    CALL extract_linked_to_table_core(
        'CODE',
        p_source_table,
        p_output_database,
        p_codelist_table,
        p_date_from,
        p_date_to,
        p_columns,
        p_output_table,
        p_overwrite_output
    );
END//

DELIMITER ;


DELIMITER //

CREATE PROCEDURE extract_linked_by_patid_to_table_default(
  IN p_source_table VARCHAR(64),
  IN p_output_database VARCHAR(128)
)
BEGIN
    DECLARE v_target_table VARCHAR(128);

    SET v_target_table = CONCAT('', p_source_table);

    CALL extract_linked_by_patid_to_table(
        p_source_table,
        p_output_database,
        'candidate_patids',
        '*',
        v_target_table,
        TRUE
    );
END//

DELIMITER ;

/* -------------------------------------------------------------------------
   5. Examples
   -------------------------------------------------------------------------

CALL extract_linked_by_patid_to_table(
    'hes_ccare',
    'aurum_oxcprd_linked_test',
    'candidate_patids',
    '*',
    'hes_ccare',
    TRUE
);

CALL extract_linked_by_code_to_table(
    'hes_diagnosis_epi',
    'aurum_oxcprd_001b',
    'dementia_codes_icd10',
    '1998-01-02',
    '2024-12-31',
    'patid,epistart,ICD',
    'dementia_hes_diagnosis_epi',
    TRUE
);

CALL extract_linked_by_code_to_table(
    'hes_diagnosis_hosp',
    'aurum_oxcprd_001b',
    'dementia_codes_icd10',
    '1998-01-02',
    '2024-12-31',
    'patid,admidate,ICD',
    'dementia_hes_diagnosis_hosp',
    TRUE
);

CALL extract_linked_by_code_to_table(
    'hes_primary_diag_hosp',
    'aurum_oxcprd_001b',
    'dementia_codes_icd10',
    '1998-01-02',
    '2024-12-31',
    'patid,admidate,ICD_PRIMARY',
    'dementia_hes_primary_diag_hosp',
    TRUE
);

CALL extract_linked_by_code_to_table(
    'hesop_clinical_apptdate',
    'aurum_oxcprd_001b',
    'dementia_codes_icd10',
    '1998-01-02',
    '2024-12-31',
    'patid,apptdate,icd',
    'dementia_hesop_clinical_apptdate',
    TRUE
);


CALL extract_linked_by_patid_to_table_default('patient_2019_imd', 'aurum_oxcprd_001b');


*/
