-- gold_linked_extract_procedures_simple_cols.sql
-- MariaDB 12.3.2
--
-- Simple extraction procedures for CPRD GOLD, HES, and linked data.
-- All source tables, codelists, patient lists, and output tables must be in
-- the database selected with USE before the procedures are called.
--
-- Each procedure replaces its output table if it already exists.
--
-- p_columns should be either '*'
-- or a comma-separated list of unqualified column names.
/* -------------------------------------------------------------------------
Extraction log
------------------------------------------------------------------------- */
CREATE TABLE IF NOT EXISTS extract_log (
  log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  procedure_name VARCHAR(64) NOT NULL,
  started_at DATETIME(6) NOT NULL,
  completed_at DATETIME(6) NULL,
  status VARCHAR(10) NOT NULL,
  source_table VARCHAR(128) NULL,
  filter_table VARCHAR(128) NULL,
  output_table VARCHAR(128) NULL,
  source_code_column VARCHAR(128) NULL,
  date_column VARCHAR(128) NULL,
  date_from DATE NULL,
  date_to DATE NULL,
  columns_selected TEXT NULL,
  rows_created BIGINT NULL,
  error_sqlstate CHAR(5) NULL,
  error_message TEXT NULL,
  PRIMARY KEY (log_id),
  INDEX idx_extract_log_started (started_at),
  INDEX idx_extract_log_status (status),
  INDEX idx_extract_log_output (output_table)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* sql-formatter-disable */
DELIMITER $$
/* sql-formatter-enable */
/* -------------------------------------------------------------------------
1. Extract any source table by patid

Required columns:
source table: patid
patient table: patid
------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS extract_by_patid$$
CREATE PROCEDURE extract_by_patid (
  IN p_source_table VARCHAR(128),
  IN p_patid_table VARCHAR(128),
  IN p_columns TEXT,
  IN p_output_table VARCHAR(128)
) SQL SECURITY INVOKER MODIFIES SQL DATA
BEGIN DECLARE v_sql LONGTEXT;

DECLARE v_rows BIGINT DEFAULT 0;

DECLARE v_cols TEXT;

DECLARE v_select_list LONGTEXT;

DECLARE v_log_id BIGINT UNSIGNED DEFAULT NULL;

DECLARE v_sqlstate CHAR(5) DEFAULT NULL;

DECLARE v_error_message TEXT DEFAULT NULL;

DECLARE EXIT
HANDLER FOR SQLEXCEPTION
BEGIN
GET DIAGNOSTICS CONDITION 1 v_sqlstate = RETURNED_SQLSTATE,
v_error_message = MESSAGE_TEXT;

UPDATE extract_log
SET
  completed_at = NOW(6),
  status = 'FAILED',
  rows_created = v_rows,
  error_sqlstate = v_sqlstate,
  error_message = v_error_message
WHERE
  log_id = v_log_id;

RESIGNAL;

END;

INSERT INTO
  extract_log (
    procedure_name,
    started_at,
    status,
    source_table,
    filter_table,
    output_table,
    columns_selected
  )
VALUES
  (
    'extract_by_patid',
    NOW(6),
    'RUNNING',
    p_source_table,
    p_patid_table,
    p_output_table,
    p_columns
  );

SET
  v_log_id = LAST_INSERT_ID();

IF DATABASE () IS NULL THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Select a database before calling the procedure';

END IF;

IF p_output_table IN (p_source_table, p_patid_table) THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Output table must differ from source and patient tables';

END IF;

SET
  v_cols = TRIM(
    REPLACE
      (
        REPLACE
          (
            REPLACE
              (COALESCE(p_columns, '*'), CHAR(9), ''),
              CHAR(10),
              ''
          ),
          CHAR(13),
          ''
      )
  );

IF v_cols = '' THEN
SET
  v_cols = '*';

END IF;

IF v_cols = '*' THEN
SET
  v_select_list = 's.*';

ELSE IF v_cols NOT REGEXP '^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$' THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'p_columns must be * or a comma-separated list of column names';

END IF;

SET
  v_select_list = CONCAT(
    's.`',
    REPLACE
      (v_cols, ',', '`, s.`'),
      '`'
  );

END IF;

SET
  v_sql = CONCAT('DROP TABLE IF EXISTS `', p_output_table, '`');

SET
  @extract_sql = v_sql;

PREPARE extract_stmt
FROM
  @extract_sql;

EXECUTE extract_stmt;

DEALLOCATE PREPARE extract_stmt;

SET
  v_sql = CONCAT(
    'CREATE TABLE `',
    p_output_table,
    '` ENGINE=InnoDB AS ',
    'SELECT ',
    v_select_list,
    ' ',
    'FROM `',
    p_source_table,
    '` AS s ',
    'WHERE EXISTS (',
    'SELECT 1 ',
    'FROM `',
    p_patid_table,
    '` AS p ',
    'WHERE p.patid = s.patid',
    ')'
  );

SET
  @extract_sql = v_sql;

PREPARE extract_stmt
FROM
  @extract_sql;

EXECUTE extract_stmt;

SET
  v_rows = ROW_COUNT ();

DEALLOCATE PREPARE extract_stmt;

UPDATE extract_log
SET
  completed_at = NOW(6),
  status = 'SUCCESS',
  rows_created = v_rows
WHERE
  log_id = v_log_id;

SELECT
  p_output_table AS output_table,
  v_rows AS rows_created;

END $$
/* -------------------------------------------------------------------------
2. Extract a CPRD GOLD table by medcode and eventdate

Required columns:
source table: medcode, eventdate
codelist: medcode
------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS extract_gold_by_medcode$$
CREATE PROCEDURE extract_gold_by_medcode (
  IN p_source_table VARCHAR(128),
  IN p_codelist_table VARCHAR(128),
  IN p_date_from DATE,
  IN p_date_to DATE,
  IN p_columns TEXT,
  IN p_output_table VARCHAR(128)
) SQL SECURITY INVOKER MODIFIES SQL DATA
BEGIN DECLARE v_sql LONGTEXT;

DECLARE v_rows BIGINT DEFAULT 0;

DECLARE v_cols TEXT;

DECLARE v_select_list LONGTEXT;

DECLARE v_log_id BIGINT UNSIGNED DEFAULT NULL;

DECLARE v_sqlstate CHAR(5) DEFAULT NULL;

DECLARE v_error_message TEXT DEFAULT NULL;

DECLARE EXIT
HANDLER FOR SQLEXCEPTION
BEGIN
GET DIAGNOSTICS CONDITION 1 v_sqlstate = RETURNED_SQLSTATE,
v_error_message = MESSAGE_TEXT;

UPDATE extract_log
SET
  completed_at = NOW(6),
  status = 'FAILED',
  rows_created = v_rows,
  error_sqlstate = v_sqlstate,
  error_message = v_error_message
WHERE
  log_id = v_log_id;

RESIGNAL;

END;

INSERT INTO
  extract_log (
    procedure_name,
    started_at,
    status,
    source_table,
    filter_table,
    output_table,
    source_code_column,
    date_column,
    date_from,
    date_to,
    columns_selected
  )
VALUES
  (
    'extract_gold_by_medcode',
    NOW(6),
    'RUNNING',
    p_source_table,
    p_codelist_table,
    p_output_table,
    'medcode',
    'eventdate',
    p_date_from,
    p_date_to,
    p_columns
  );

SET
  v_log_id = LAST_INSERT_ID();

IF DATABASE () IS NULL THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Select a database before calling the procedure';

END IF;

IF p_date_from IS NULL
OR p_date_to IS NULL THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Both date parameters are required';

END IF;

IF p_date_from > p_date_to THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'p_date_from must not exceed p_date_to';

END IF;

IF p_output_table IN (p_source_table, p_codelist_table) THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Output table must differ from source and codelist tables';

END IF;

SET
  v_cols = TRIM(
    REPLACE
      (
        REPLACE
          (
            REPLACE
              (COALESCE(p_columns, '*'), CHAR(9), ''),
              CHAR(10),
              ''
          ),
          CHAR(13),
          ''
      )
  );

IF v_cols = '' THEN
SET
  v_cols = '*';

END IF;

IF v_cols = '*' THEN
SET
  v_select_list = 's.*';

ELSE IF v_cols NOT REGEXP '^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$' THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'p_columns must be * or a comma-separated list of column names';

END IF;

SET
  v_select_list = CONCAT(
    's.`',
    REPLACE
      (v_cols, ',', '`, s.`'),
      '`'
  );

END IF;

SET
  v_sql = CONCAT('DROP TABLE IF EXISTS `', p_output_table, '`');

SET
  @extract_sql = v_sql;

PREPARE extract_stmt
FROM
  @extract_sql;

EXECUTE extract_stmt;

DEALLOCATE PREPARE extract_stmt;

SET
  v_sql = CONCAT(
    'CREATE TABLE `',
    p_output_table,
    '` ENGINE=InnoDB AS ',
    'SELECT ',
    v_select_list,
    ' ',
    'FROM `',
    p_source_table,
    '` AS s ',
    'WHERE EXISTS (',
    'SELECT 1 ',
    'FROM `',
    p_codelist_table,
    '` AS c ',
    'WHERE c.medcode = s.medcode',
    ') ',
    'AND s.eventdate >= ? ',
    'AND s.eventdate < DATE_ADD(?, INTERVAL 1 DAY)'
  );

SET
  @extract_sql = v_sql;

SET
  @date_from = p_date_from;

SET
  @date_to = p_date_to;

PREPARE extract_stmt
FROM
  @extract_sql;

EXECUTE extract_stmt USING @date_from,
@date_to;

SET
  v_rows = ROW_COUNT ();

DEALLOCATE PREPARE extract_stmt;

UPDATE extract_log
SET
  completed_at = NOW(6),
  status = 'SUCCESS',
  rows_created = v_rows
WHERE
  log_id = v_log_id;

SELECT
  p_output_table AS output_table,
  v_rows AS rows_created;

END $$
/* -------------------------------------------------------------------------
3. Extract a CPRD GOLD therapy table by prodcode and eventdate

Required columns:
source table: prodcode, eventdate
codelist: prodcode
------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS extract_gold_by_prodcode$$
CREATE PROCEDURE extract_gold_by_prodcode (
  IN p_source_table VARCHAR(128),
  IN p_codelist_table VARCHAR(128),
  IN p_date_from DATE,
  IN p_date_to DATE,
  IN p_columns TEXT,
  IN p_output_table VARCHAR(128)
) SQL SECURITY INVOKER MODIFIES SQL DATA
BEGIN DECLARE v_sql LONGTEXT;

DECLARE v_rows BIGINT DEFAULT 0;

DECLARE v_cols TEXT;

DECLARE v_select_list LONGTEXT;

DECLARE v_log_id BIGINT UNSIGNED DEFAULT NULL;

DECLARE v_sqlstate CHAR(5) DEFAULT NULL;

DECLARE v_error_message TEXT DEFAULT NULL;

DECLARE EXIT
HANDLER FOR SQLEXCEPTION
BEGIN
GET DIAGNOSTICS CONDITION 1 v_sqlstate = RETURNED_SQLSTATE,
v_error_message = MESSAGE_TEXT;

UPDATE extract_log
SET
  completed_at = NOW(6),
  status = 'FAILED',
  rows_created = v_rows,
  error_sqlstate = v_sqlstate,
  error_message = v_error_message
WHERE
  log_id = v_log_id;

RESIGNAL;

END;

INSERT INTO
  extract_log (
    procedure_name,
    started_at,
    status,
    source_table,
    filter_table,
    output_table,
    source_code_column,
    date_column,
    date_from,
    date_to,
    columns_selected
  )
VALUES
  (
    'extract_gold_by_prodcode',
    NOW(6),
    'RUNNING',
    p_source_table,
    p_codelist_table,
    p_output_table,
    'prodcode',
    'eventdate',
    p_date_from,
    p_date_to,
    p_columns
  );

SET
  v_log_id = LAST_INSERT_ID();

IF DATABASE () IS NULL THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Select a database before calling the procedure';

END IF;

IF p_date_from IS NULL
OR p_date_to IS NULL THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Both date parameters are required';

END IF;

IF p_date_from > p_date_to THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'p_date_from must not exceed p_date_to';

END IF;

IF p_output_table IN (p_source_table, p_codelist_table) THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Output table must differ from source and codelist tables';

END IF;

SET
  v_cols = TRIM(
    REPLACE
      (
        REPLACE
          (
            REPLACE
              (COALESCE(p_columns, '*'), CHAR(9), ''),
              CHAR(10),
              ''
          ),
          CHAR(13),
          ''
      )
  );

IF v_cols = '' THEN
SET
  v_cols = '*';

END IF;

IF v_cols = '*' THEN
SET
  v_select_list = 's.*';

ELSE IF v_cols NOT REGEXP '^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$' THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'p_columns must be * or a comma-separated list of column names';

END IF;

SET
  v_select_list = CONCAT(
    's.`',
    REPLACE
      (v_cols, ',', '`, s.`'),
      '`'
  );

END IF;

SET
  v_sql = CONCAT('DROP TABLE IF EXISTS `', p_output_table, '`');

SET
  @extract_sql = v_sql;

PREPARE extract_stmt
FROM
  @extract_sql;

EXECUTE extract_stmt;

DEALLOCATE PREPARE extract_stmt;

SET
  v_sql = CONCAT(
    'CREATE TABLE `',
    p_output_table,
    '` ENGINE=InnoDB AS ',
    'SELECT ',
    v_select_list,
    ' ',
    'FROM `',
    p_source_table,
    '` AS s ',
    'WHERE EXISTS (',
    'SELECT 1 ',
    'FROM `',
    p_codelist_table,
    '` AS c ',
    'WHERE c.prodcode = s.prodcode',
    ') ',
    'AND s.eventdate >= ? ',
    'AND s.eventdate < DATE_ADD(?, INTERVAL 1 DAY)'
  );

SET
  @extract_sql = v_sql;

SET
  @date_from = p_date_from;

SET
  @date_to = p_date_to;

PREPARE extract_stmt
FROM
  @extract_sql;

EXECUTE extract_stmt USING @date_from,
@date_to;

SET
  v_rows = ROW_COUNT ();

DEALLOCATE PREPARE extract_stmt;

UPDATE extract_log
SET
  completed_at = NOW(6),
  status = 'SUCCESS',
  rows_created = v_rows
WHERE
  log_id = v_log_id;

SELECT
  p_output_table AS output_table,
  v_rows AS rows_created;

END $$
/* -------------------------------------------------------------------------
4. Extract a HES or linked table by an ICD-10 source column and date column

Required columns:
source table: caller-supplied ICD-10 column and date column
codelist: icd10
------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS extract_linked_by_icd10$$
CREATE PROCEDURE extract_linked_by_icd10 (
  IN p_source_table VARCHAR(128),
  IN p_codelist_table VARCHAR(128),
  IN p_source_icd_column VARCHAR(128),
  IN p_date_column VARCHAR(128),
  IN p_date_from DATE,
  IN p_date_to DATE,
  IN p_columns TEXT,
  IN p_output_table VARCHAR(128)
) SQL SECURITY INVOKER MODIFIES SQL DATA
BEGIN DECLARE v_sql LONGTEXT;

DECLARE v_rows BIGINT DEFAULT 0;

DECLARE v_cols TEXT;

DECLARE v_select_list LONGTEXT;

DECLARE v_log_id BIGINT UNSIGNED DEFAULT NULL;

DECLARE v_sqlstate CHAR(5) DEFAULT NULL;

DECLARE v_error_message TEXT DEFAULT NULL;

DECLARE EXIT
HANDLER FOR SQLEXCEPTION
BEGIN
GET DIAGNOSTICS CONDITION 1 v_sqlstate = RETURNED_SQLSTATE,
v_error_message = MESSAGE_TEXT;

UPDATE extract_log
SET
  completed_at = NOW(6),
  status = 'FAILED',
  rows_created = v_rows,
  error_sqlstate = v_sqlstate,
  error_message = v_error_message
WHERE
  log_id = v_log_id;

RESIGNAL;

END;

INSERT INTO
  extract_log (
    procedure_name,
    started_at,
    status,
    source_table,
    filter_table,
    output_table,
    source_code_column,
    date_column,
    date_from,
    date_to,
    columns_selected
  )
VALUES
  (
    'extract_linked_by_icd10',
    NOW(6),
    'RUNNING',
    p_source_table,
    p_codelist_table,
    p_output_table,
    p_source_icd_column,
    p_date_column,
    p_date_from,
    p_date_to,
    p_columns
  );

SET
  v_log_id = LAST_INSERT_ID();

IF DATABASE () IS NULL THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Select a database before calling the procedure';

END IF;

IF p_date_from IS NULL
OR p_date_to IS NULL THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Both date parameters are required';

END IF;

IF p_date_from > p_date_to THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'p_date_from must not exceed p_date_to';

END IF;

IF p_output_table IN (p_source_table, p_codelist_table) THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Output table must differ from source and codelist tables';

END IF;

SET
  v_cols = TRIM(
    REPLACE
      (
        REPLACE
          (
            REPLACE
              (COALESCE(p_columns, '*'), CHAR(9), ''),
              CHAR(10),
              ''
          ),
          CHAR(13),
          ''
      )
  );

IF v_cols = '' THEN
SET
  v_cols = '*';

END IF;

IF v_cols = '*' THEN
SET
  v_select_list = 's.*';

ELSE IF v_cols NOT REGEXP '^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$' THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'p_columns must be * or a comma-separated list of column names';

END IF;

SET
  v_select_list = CONCAT(
    's.`',
    REPLACE
      (v_cols, ',', '`, s.`'),
      '`'
  );

END IF;

SET
  v_sql = CONCAT('DROP TABLE IF EXISTS `', p_output_table, '`');

SET
  @extract_sql = v_sql;

PREPARE extract_stmt
FROM
  @extract_sql;

EXECUTE extract_stmt;

DEALLOCATE PREPARE extract_stmt;

SET
  v_sql = CONCAT(
    'CREATE TABLE `',
    p_output_table,
    '` ENGINE=InnoDB AS ',
    'SELECT ',
    v_select_list,
    ' ',
    'FROM `',
    p_source_table,
    '` AS s ',
    'WHERE EXISTS (',
    'SELECT 1 ',
    'FROM `',
    p_codelist_table,
    '` AS c ',
    'WHERE c.icd10 = s.`',
    p_source_icd_column,
    '`',
    ') ',
    'AND s.`',
    p_date_column,
    '` >= ? ',
    'AND s.`',
    p_date_column,
    '` < DATE_ADD(?, INTERVAL 1 DAY)'
  );

SET
  @extract_sql = v_sql;

SET
  @date_from = p_date_from;

SET
  @date_to = p_date_to;

PREPARE extract_stmt
FROM
  @extract_sql;

EXECUTE extract_stmt USING @date_from,
@date_to;

SET
  v_rows = ROW_COUNT ();

DEALLOCATE PREPARE extract_stmt;

UPDATE extract_log
SET
  completed_at = NOW(6),
  status = 'SUCCESS',
  rows_created = v_rows
WHERE
  log_id = v_log_id;

SELECT
  p_output_table AS output_table,
  v_rows AS rows_created;

END $$ /* sql-formatter-disable */
DELIMITER ;
/* sql-formatter-enable */
/* -------------------------------------------------------------------------
Examples
-------------------------------------------------------------------------

-- Any CPRD, HES, or linked table by patient list:
CALL extract_by_patid(
'clinical',
'patids',
'patid,eventdate,medcode',
'clinical'
);

-- CPRD GOLD clinical table by medcode and eventdate:
CALL extract_gold_by_medcode(
'clinical',
'v1_5_dementia_codes_GOLD',
'2000-01-01',
'2025-12-31',
'patid,eventdate,medcode',
'dementia_clinical'
);

-- CPRD GOLD therapy table by prodcode and eventdate:
CALL extract_gold_by_prodcode(
'therapy',
'v1_2_dementia_drug_GOLD',
'2000-01-01',
'2025-12-31',
'patid,eventdate,prodcode',
'dementia_therapy'
);

-- HES diagnosis table where the source code column is ICD:
CALL extract_linked_by_icd10(
'hes_diagnosis_epi',
'dementia_codes_icd10',
'ICD',
'epistart',
'2000-01-01',
'2025-12-31',
'patid,epistart,ICD',
'dementia_hes_epi'
);

-- HES primary diagnosis table where the source code column is ICD_PRIMARY:
CALL extract_linked_by_icd10(
'hes_primary_diag_hosp',
'dementia_codes_icd10',
'ICD_PRIMARY',
'admidate',
'2000-01-01',
'2025-12-31',
'patid,admidate,ICD_PRIMARY',
'dementia_hes_primary'
);
*/
