-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
\W
USE gold;

-- Derived pracid for patient-linked tables uses the last 5 digits of patid,

SET SESSION foreign_key_checks = 0;
SET SESSION unique_checks      = 0;

-- ============================================================
-- Import progress table
-- ============================================================

CREATE TABLE IF NOT EXISTS gold_import_progress (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  target_table VARCHAR(64) NOT NULL,
  source_folder VARCHAR(64) NOT NULL,
  source_file VARCHAR(128) NOT NULL,
  source_path VARCHAR(1024) NOT NULL,
  file_no INT UNSIGNED NOT NULL,
  status ENUM('started','success','failed') NOT NULL,
  started_at DATETIME NULL,
  finished_at DATETIME NULL,
  rows_loaded BIGINT NULL,
  mysql_errno INT NULL,
  message TEXT NULL,
  attempts INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_gold_import_file (target_table, source_file),
  KEY idx_gold_import_status (target_table, status),
  KEY idx_gold_import_started (started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Template tables.
-- ============================================================

CREATE TABLE IF NOT EXISTS tpl_practice_raw (
  pracid MEDIUMINT,
  lcd DATE,
  uts DATE,
  region TINYINT UNSIGNED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_staff_raw (
  staffid BIGINT UNSIGNED,
  gender SMALLINT UNSIGNED,
  role TINYINT UNSIGNED,
  pracid MEDIUMINT 

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_patient_raw (
  patid BIGINT UNSIGNED,
  pracid MEDIUMINT,
  vmid BIGINT UNSIGNED,
  gender TINYINT UNSIGNED,
  yob SMALLINT UNSIGNED,
  mob TINYINT UNSIGNED,
  marital TINYINT UNSIGNED,
  famnum BIGINT UNSIGNED,
  chsreg TINYINT UNSIGNED,
  chsdate DATE,
  prescr TINYINT UNSIGNED,
  capsup TINYINT UNSIGNED,
  frd DATE,
  crd DATE,
  regstat INT UNSIGNED,
  reggap INT UNSIGNED,
  internal INT UNSIGNED,
  tod DATE,
  toreason TINYINT UNSIGNED,
  deathdate DATE,
  accept TINYINT UNSIGNED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_consultation_raw (
  patid BIGINT UNSIGNED,
  pracid INT UNSIGNED,
  eventdate DATE,
  sysdate DATE,
  constype TINYINT UNSIGNED,
  consid BIGINT UNSIGNED,
  staffid BIGINT UNSIGNED,
  duration BIGINT UNSIGNED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_clinical_raw (
  patid BIGINT UNSIGNED,
  pracid INT UNSIGNED,
  eventdate DATE,
  sysdate DATE,
  constype TINYINT UNSIGNED,
  consid BIGINT UNSIGNED,
  medcode INT UNSIGNED,
  sctid TEXT,
  sctdescid TEXT,
  sctexpression TEXT,
  sctmaptype INT UNSIGNED,
  sctmapversion BIGINT UNSIGNED,
  sctisindicative VARCHAR(10),
  sctisassured VARCHAR(10),
  staffid BIGINT UNSIGNED,
  episode TINYINT UNSIGNED,
  enttype SMALLINT UNSIGNED,
  adid BIGINT UNSIGNED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_additional_raw (
  patid BIGINT UNSIGNED,
  pracid INT UNSIGNED,
  enttype SMALLINT UNSIGNED,
  adid BIGINT,
  data1 TEXT,
  data2 TEXT,
  data3 TEXT,
  data4 TEXT,
  data5 TEXT,
  data6 TEXT,
  data7 TEXT,
  data8 TEXT,
  data9 TEXT,
  data10 TEXT,
  data11 TEXT,
  data12 TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_referral_raw (
  patid BIGINT UNSIGNED,
  pracid INT UNSIGNED,
  eventdate DATE,
  sysdate DATE,
  constype TINYINT UNSIGNED,
  consid BIGINT UNSIGNED,
  medcode INT UNSIGNED,
  sctid TEXT,
  sctdescid TEXT,
  sctexpression TEXT,
  sctmaptype INT UNSIGNED,
  sctmapversion BIGINT UNSIGNED,
  sctisindicative VARCHAR(10),
  sctisassured VARCHAR(10),
  staffid BIGINT UNSIGNED,
  source TINYINT UNSIGNED,
  nhsspec TINYINT UNSIGNED,
  fhsaspec TINYINT UNSIGNED,
  inpatient TINYINT UNSIGNED,
  attendance TINYINT UNSIGNED,
  urgency TINYINT UNSIGNED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_immunisation_raw (
  patid BIGINT UNSIGNED,
  pracid INT UNSIGNED,
  eventdate DATE,
  sysdate DATE,
  constype TINYINT UNSIGNED,
  consid BIGINT UNSIGNED,
  medcode INT UNSIGNED,
  sctid TEXT,
  sctdescid TEXT,
  sctexpression TEXT,
  sctmaptype INT UNSIGNED,
  sctmapversion BIGINT UNSIGNED,
  sctisindicative VARCHAR(10),
  sctisassured VARCHAR(10),
  staffid BIGINT UNSIGNED,
  immstype SMALLINT UNSIGNED,
  stage TINYINT UNSIGNED,
  status TINYINT UNSIGNED,
  compound TINYINT UNSIGNED,
  source TINYINT UNSIGNED,
  reason TINYINT UNSIGNED,
  method TINYINT UNSIGNED,
  batch BIGINT UNSIGNED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_test_raw (
  patid BIGINT UNSIGNED,
  pracid INT UNSIGNED,
  eventdate DATE,
  sysdate DATE,
  constype TINYINT UNSIGNED,
  consid BIGINT UNSIGNED,
  medcode INT UNSIGNED,
  sctid TEXT,
  sctdescid TEXT,
  sctexpression TEXT,
  sctmaptype INT UNSIGNED,
  sctmapversion BIGINT UNSIGNED,
  sctisindicative VARCHAR(10),
  sctisassured VARCHAR(10),
  staffid BIGINT UNSIGNED,
  enttype SMALLINT UNSIGNED,
  data1 TEXT,
  data2 TEXT,
  data3 TEXT,
  data4 TEXT,
  data5 TEXT,
  data6 TEXT,
  data7 TEXT,
  data8 TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_therapy_raw (
  patid BIGINT UNSIGNED,
  pracid INT UNSIGNED,
  eventdate DATE,
  sysdate DATE,
  consid BIGINT UNSIGNED,
  prodcode INT UNSIGNED,
  drugdmd TEXT,
  staffid BIGINT UNSIGNED,
  dosageid TEXT,
  bnfcode SMALLINT UNSIGNED,
  qty decimal(9,3),
  numdays decimal(9,3),
  numpacks decimal(9,3),
  packtype INT UNSIGNED,
  issueseq BIGINT UNSIGNED,
  prn TINYINT

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- Import tables
-- ============================================================

CREATE TABLE IF NOT EXISTS practice LIKE tpl_practice_raw;
CREATE TABLE IF NOT EXISTS staff LIKE tpl_staff_raw;
CREATE TABLE IF NOT EXISTS patient LIKE tpl_patient_raw;
CREATE TABLE IF NOT EXISTS referral LIKE tpl_referral_raw;

CREATE TABLE IF NOT EXISTS consultation_001 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_002 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_003 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_004 LIKE tpl_consultation_raw;

CREATE TABLE IF NOT EXISTS clinical_001 LIKE tpl_clinical_raw;
CREATE TABLE IF NOT EXISTS clinical_002 LIKE tpl_clinical_raw;
CREATE TABLE IF NOT EXISTS clinical_003 LIKE tpl_clinical_raw;


CREATE TABLE IF NOT EXISTS additional LIKE tpl_additional_raw;

CREATE TABLE IF NOT EXISTS immunisation LIKE tpl_immunisation_raw;

CREATE TABLE IF NOT EXISTS test_001 LIKE tpl_test_raw;
CREATE TABLE IF NOT EXISTS test_002 LIKE tpl_test_raw;

CREATE TABLE IF NOT EXISTS therapy_001 LIKE tpl_therapy_raw;
CREATE TABLE IF NOT EXISTS therapy_002 LIKE tpl_therapy_raw;
CREATE TABLE IF NOT EXISTS therapy_003 LIKE tpl_therapy_raw;


-- ============================================================
-- Procedures
-- ============================================================

-- DROP PROCEDURE IF EXISTS load_gold_file_raw;
-- DROP PROCEDURE IF EXISTS load_gold_range_raw;
-- DROP PROCEDURE IF EXISTS gold_import_summary;

/* sql-formatter-disable */
DELIMITER $$
/* sql-formatter-enable */

CREATE PROCEDURE load_gold_file_raw(
  IN p_target_table VARCHAR(64),
  IN p_file_type VARCHAR(32),
  IN p_source_folder VARCHAR(64),
  IN p_file_prefix VARCHAR(64),
  IN p_file_no INT UNSIGNED
)
proc: BEGIN
  DECLARE v_root VARCHAR(1024) DEFAULT '{{DATA_ROOT}}/Gold_JAN2026';
  DECLARE v_file_type_norm VARCHAR(64);
  DECLARE v_file_prefix VARCHAR(64);
  DECLARE v_file_no_txt CHAR(4);
  DECLARE v_source_file VARCHAR(128);
  DECLARE v_source_path VARCHAR(1024);
  DECLARE v_already_done INT DEFAULT 0;
  DECLARE v_rows BIGINT DEFAULT 0;
  DECLARE v_errno INT DEFAULT NULL;
  DECLARE v_message TEXT DEFAULT NULL;
  DECLARE v_ignore_lines VARCHAR(32) DEFAULT '';
  DECLARE v_target_table_sql VARCHAR(96);
  DECLARE v_columns TEXT DEFAULT NULL;
  DECLARE v_set_clause TEXT DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_message = MESSAGE_TEXT;

    UPDATE gold_import_progress
       SET status = 'failed',
           finished_at = NOW(),
           mysql_errno = v_errno,
           message = v_message
     WHERE target_table = p_target_table
       AND source_file = v_source_file;

    RESIGNAL;
  END;

  SET v_file_type_norm = LOWER(p_file_type);
  SET v_file_prefix = p_file_prefix;

  SET v_file_no_txt = CASE
    WHEN p_file_no < 1000 THEN LPAD(p_file_no, 3, '0')
    ELSE CAST(p_file_no AS CHAR)
  END;
  SET v_source_file = CONCAT(v_file_prefix, '_', v_file_no_txt, '.txt');
  SET v_source_path = CONCAT(v_root, '/', p_source_folder, '/', v_source_file);
  SET v_ignore_lines = '';

  IF p_file_no = 1 THEN
    SET v_ignore_lines = 'IGNORE 1 LINES ';
  END IF;

  SELECT COUNT(*)
    INTO v_already_done
    FROM gold_import_progress
   WHERE target_table = p_target_table
     AND source_file = v_source_file
     AND status = 'success';

  IF v_already_done > 0 THEN
    LEAVE proc;
  END IF;

  INSERT INTO gold_import_progress
    (target_table, source_folder, source_file, source_path, file_no,
     status, started_at, finished_at, rows_loaded, mysql_errno, message, attempts)
  VALUES
    (p_target_table, p_source_folder, v_source_file, v_source_path, p_file_no,
     'started', NOW(), NULL, NULL, NULL, NULL, 1)
  ON DUPLICATE KEY UPDATE
     source_folder = VALUES(source_folder),
     source_path = VALUES(source_path),
     file_no = VALUES(file_no),
     status = 'started',
     started_at = NOW(),
     finished_at = NULL,
     rows_loaded = NULL,
     mysql_errno = NULL,
     message = NULL,
     attempts = attempts + 1;

  SET v_target_table_sql = CONCAT('`', REPLACE(p_target_table, '`', '``'), '`');

  IF v_file_type_norm = 'practice' THEN
    SET v_columns = '(@pracid, @region, @lcd, @uts)';
    SET v_set_clause = 'pracid = NULLIF(@pracid, ''''), region = NULLIF(@region, ''''), lcd = NULLIF(@lcd, ''''), uts = NULLIF(@uts, '''')';

  ELSEIF v_file_type_norm = 'staff' THEN
    SET v_columns = '(@staffid, @gender, @role)';
    SET v_set_clause = 'staffid = NULLIF(@staffid, ''''), gender = NULLIF(@gender, ''''), role = NULLIF(@role, ''''), pracid = CASE WHEN @staffid IS NULL OR CHAR_LENGTH(CAST(@staffid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@staffid AS CHAR), CHAR_LENGTH(CAST(@staffid AS CHAR)) - 4, 5) END';

  ELSEIF v_file_type_norm = 'patient' THEN
    SET v_columns = '(@patid, @vmid, @gender, @yob, @mob, @marital, @famnum, @chsreg, @chsdate, @prescr, @capsup, @frd, @crd, @regstat, @reggap, @internal, @tod, @toreason, @deathdate, @accept)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = CASE WHEN @patid IS NULL OR CHAR_LENGTH(CAST(@patid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@patid AS CHAR), CHAR_LENGTH(CAST(@patid AS CHAR)) - 4, 5) END, vmid = NULLIF(@vmid, ''''), gender = NULLIF(@gender, ''''), yob = CASE WHEN NULLIF(@yob, '''') IS NULL THEN NULL ELSE CAST(@yob AS UNSIGNED) + 1800 END, mob = NULLIF(@mob, ''''), marital = NULLIF(@marital, ''''), famnum = NULLIF(@famnum, ''''), chsreg = NULLIF(@chsreg, ''''), chsdate = NULLIF(@chsdate, ''''), prescr = NULLIF(@prescr, ''''), capsup = NULLIF(@capsup, ''''), frd = NULLIF(@frd, ''''), crd = NULLIF(@crd, ''''), regstat = NULLIF(@regstat, ''''), reggap = NULLIF(@reggap, ''''), internal = NULLIF(@internal, ''''), tod = NULLIF(@tod, ''''), toreason = NULLIF(@toreason, ''''), deathdate = NULLIF(@deathdate, ''''), accept = NULLIF(@accept, '''')';

  ELSEIF v_file_type_norm = 'consultation' THEN
    SET v_columns = '(@consid, @patid, @eventdate, @sysdate, @constype, @staffid, @duration)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = CASE WHEN @patid IS NULL OR CHAR_LENGTH(CAST(@patid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@patid AS CHAR), CHAR_LENGTH(CAST(@patid AS CHAR)) - 4, 5) END, eventdate = NULLIF(@eventdate, ''''), sysdate = NULLIF(@sysdate, ''''), constype = NULLIF(@constype, ''''), consid = NULLIF(@consid, ''''), staffid = NULLIF(@staffid, ''''), duration = NULLIF(@duration, '''')';

  ELSEIF v_file_type_norm = 'clinical' THEN
    SET v_columns = '(@patid, @eventdate, @sysdate, @constype, @consid, @medcode, @sctid, @sctdescid, @sctexpression, @sctmaptype, @sctmapversion, @sctisindicative, @sctisassured, @staffid, @episode, @enttype, @adid)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = CASE WHEN @patid IS NULL OR CHAR_LENGTH(CAST(@patid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@patid AS CHAR), CHAR_LENGTH(CAST(@patid AS CHAR)) - 4, 5) END, eventdate = NULLIF(@eventdate, ''''), sysdate = NULLIF(@sysdate, ''''), constype = NULLIF(@constype, ''''), consid = NULLIF(@consid, ''''), medcode = NULLIF(@medcode, ''''), sctid = NULLIF(@sctid, ''''), sctdescid = NULLIF(@sctdescid, ''''), sctexpression = NULLIF(@sctexpression, ''''), sctmaptype = NULLIF(@sctmaptype, ''''), sctmapversion = NULLIF(@sctmapversion, ''''), sctisindicative = NULLIF(@sctisindicative, ''''), sctisassured = NULLIF(@sctisassured, ''''), staffid = NULLIF(@staffid, ''''), episode = NULLIF(@episode, ''''), enttype = NULLIF(@enttype, ''''), adid = NULLIF(@adid, '''')';

  ELSEIF v_file_type_norm = 'additional' THEN
    SET v_columns = '(@patid, @enttype, @adid, @data1, @data2, @data3, @data4, @data5, @data6, @data7, @data8, @data9, @data10, @data11, @data12)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = CASE WHEN @patid IS NULL OR CHAR_LENGTH(CAST(@patid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@patid AS CHAR), CHAR_LENGTH(CAST(@patid AS CHAR)) - 4, 5) END, enttype = NULLIF(@enttype, ''''), adid = NULLIF(@adid, ''''), data1 = NULLIF(@data1, ''''), data2 = NULLIF(@data2, ''''), data3 = NULLIF(@data3, ''''), data4 = NULLIF(@data4, ''''), data5 = NULLIF(@data5, ''''), data6 = NULLIF(@data6, ''''), data7 = NULLIF(@data7, ''''), data8 = NULLIF(@data8, ''''), data9 = NULLIF(@data9, ''''), data10 = NULLIF(@data10, ''''), data11 = NULLIF(@data11, ''''), data12 = NULLIF(@data12, '''')';

  ELSEIF v_file_type_norm = 'referral' THEN
    SET v_columns = '(@patid, @eventdate, @sysdate, @constype, @consid, @medcode, @sctid, @sctdescid, @sctexpression, @sctmaptype, @sctmapversion, @sctisindicative, @sctisassured, @staffid, @source, @nhsspec, @fhsaspec, @inpatient, @attendance, @urgency)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = CASE WHEN @patid IS NULL OR CHAR_LENGTH(CAST(@patid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@patid AS CHAR), CHAR_LENGTH(CAST(@patid AS CHAR)) - 4, 5) END, eventdate = NULLIF(@eventdate, ''''), sysdate = NULLIF(@sysdate, ''''), constype = NULLIF(@constype, ''''), consid = NULLIF(@consid, ''''), medcode = NULLIF(@medcode, ''''), sctid = NULLIF(@sctid, ''''), sctdescid = NULLIF(@sctdescid, ''''), sctexpression = NULLIF(@sctexpression, ''''), sctmaptype = NULLIF(@sctmaptype, ''''), sctmapversion = NULLIF(@sctmapversion, ''''), sctisindicative = NULLIF(@sctisindicative, ''''), sctisassured = NULLIF(@sctisassured, ''''), staffid = NULLIF(@staffid, ''''), source = NULLIF(@source, ''''), nhsspec = NULLIF(@nhsspec, ''''), fhsaspec = NULLIF(@fhsaspec, ''''), inpatient = NULLIF(@inpatient, ''''), attendance = NULLIF(@attendance, ''''), urgency = NULLIF(@urgency, '''')';

  ELSEIF v_file_type_norm = 'immunisation' THEN
    SET v_columns = '(@patid, @eventdate, @sysdate, @constype, @consid, @medcode, @sctid, @sctdescid, @sctexpression, @sctmaptype, @sctmapversion, @sctisindicative, @sctisassured, @staffid, @immstype, @stage, @status, @compound, @source, @reason, @method, @batch)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = CASE WHEN @patid IS NULL OR CHAR_LENGTH(CAST(@patid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@patid AS CHAR), CHAR_LENGTH(CAST(@patid AS CHAR)) - 4, 5) END, eventdate = NULLIF(@eventdate, ''''), sysdate = NULLIF(@sysdate, ''''), constype = NULLIF(@constype, ''''), consid = NULLIF(@consid, ''''), medcode = NULLIF(@medcode, ''''), sctid = NULLIF(@sctid, ''''), sctdescid = NULLIF(@sctdescid, ''''), sctexpression = NULLIF(@sctexpression, ''''), sctmaptype = NULLIF(@sctmaptype, ''''), sctmapversion = NULLIF(@sctmapversion, ''''), sctisindicative = NULLIF(@sctisindicative, ''''), sctisassured = NULLIF(@sctisassured, ''''), staffid = NULLIF(@staffid, ''''), immstype = NULLIF(@immstype, ''''), stage = NULLIF(@stage, ''''), status = NULLIF(@status, ''''), compound = NULLIF(@compound, ''''), source = NULLIF(@source, ''''), reason = NULLIF(@reason, ''''), method = NULLIF(@method, ''''), batch = NULLIF(@batch, '''')';

  ELSEIF v_file_type_norm = 'test' THEN
    SET v_columns = '(@patid, @eventdate, @sysdate, @constype, @consid, @medcode, @sctid, @sctdescid, @sctexpression, @sctmaptype, @sctmapversion, @sctisindicative, @sctisassured, @staffid, @enttype, @data1, @data2, @data3, @data4, @data5, @data6, @data7, @data8)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = CASE WHEN @patid IS NULL OR CHAR_LENGTH(CAST(@patid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@patid AS CHAR), CHAR_LENGTH(CAST(@patid AS CHAR)) - 4, 5) END, eventdate = NULLIF(@eventdate, ''''), sysdate = NULLIF(@sysdate, ''''), constype = NULLIF(@constype, ''''), consid = NULLIF(@consid, ''''), medcode = NULLIF(@medcode, ''''), sctid = NULLIF(@sctid, ''''), sctdescid = NULLIF(@sctdescid, ''''), sctexpression = NULLIF(@sctexpression, ''''), sctmaptype = NULLIF(@sctmaptype, ''''), sctmapversion = NULLIF(@sctmapversion, ''''), sctisindicative = NULLIF(@sctisindicative, ''''), sctisassured = NULLIF(@sctisassured, ''''), staffid = NULLIF(@staffid, ''''), enttype = NULLIF(@enttype, ''''), data1 = NULLIF(@data1, ''''), data2 = NULLIF(@data2, ''''), data3 = NULLIF(@data3, ''''), data4 = NULLIF(@data4, ''''), data5 = NULLIF(@data5, ''''), data6 = NULLIF(@data6, ''''), data7 = NULLIF(@data7, ''''), data8 = NULLIF(@data8, '''')';

  ELSEIF v_file_type_norm = 'therapy' THEN
    SET v_columns = '(@patid, @eventdate, @sysdate, @consid, @prodcode, @drugdmd, @staffid, @dosageid, @bnfcode, @qty, @numdays, @numpacks, @packtype, @issueseq, @prn)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = CASE WHEN @patid IS NULL OR CHAR_LENGTH(CAST(@patid AS CHAR)) < 5 THEN NULL ELSE SUBSTR(CAST(@patid AS CHAR), CHAR_LENGTH(CAST(@patid AS CHAR)) - 4, 5) END, eventdate = NULLIF(@eventdate, ''''), sysdate = NULLIF(@sysdate, ''''), consid = NULLIF(@consid, ''''), prodcode = NULLIF(@prodcode, ''''), drugdmd = NULLIF(@drugdmd, ''''), staffid = NULLIF(@staffid, ''''), dosageid = NULLIF(@dosageid, ''''), bnfcode = NULLIF(@bnfcode, ''''), qty = NULLIF(@qty, ''''), numdays = NULLIF(@numdays, ''''), numpacks = NULLIF(@numpacks, ''''), packtype = NULLIF(@packtype, ''''), issueseq = NULLIF(@issueseq, ''''), prn = NULLIF(@prn, '''')';

  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown file type passed to load_gold_file_raw';
  END IF;

  SET @load_sql = CONCAT(
    'LOAD DATA INFILE ', QUOTE(v_source_path), ' IGNORE ',
    'INTO TABLE gold.', v_target_table_sql, ' ',
    'FIELDS TERMINATED BY '','' ',
    'LINES TERMINATED BY ''\r\n'' ',
    v_ignore_lines,
    v_columns,
    ' SET ', v_set_clause
  );

  PREPARE stmt FROM @load_sql;
  EXECUTE stmt;
  SET v_rows = ROW_COUNT();
  DEALLOCATE PREPARE stmt;

  UPDATE gold_import_progress
     SET status = 'success',
         finished_at = NOW(),
         rows_loaded = v_rows,
         mysql_errno = NULL,
         message = 'Imported successfully'
   WHERE target_table = p_target_table
     AND source_file = v_source_file;
END$$

CREATE PROCEDURE load_gold_range_raw(
  IN p_target_table VARCHAR(64),
  IN p_file_type VARCHAR(32),
  IN p_source_folder VARCHAR(64),
  IN p_file_prefix VARCHAR(64),
  IN p_first_file INT UNSIGNED,
  IN p_last_file INT UNSIGNED
)
BEGIN
  DECLARE i INT UNSIGNED;

  SET i = p_first_file;
  WHILE i <= p_last_file DO
    CALL load_gold_file_raw(p_target_table, p_file_type, p_source_folder, p_file_prefix, i);
    SET i = i + 1;
  END WHILE;
END$$

CREATE PROCEDURE gold_import_summary()
BEGIN
  SELECT target_table,
         COUNT(*) AS files_attempted,
         SUM(status = 'success') AS files_success,
         SUM(status = 'failed') AS files_failed,
         SUM(rows_loaded) AS rows_loaded,
         MIN(started_at) AS first_started_at,
         MAX(finished_at) AS last_finished_at
    FROM gold_import_progress
   GROUP BY target_table
   ORDER BY target_table;
END$$

/* sql-formatter-disable */
DELIMITER ;
/* sql-formatter-enable */

-- ============================================================

-- ============================================================

-- CALL gold_import_summary();

-- Restore durability after all bulk loads are complete:
-- SET GLOBAL innodb_flush_log_at_trx_commit = 1;
-- SET SESSION foreign_key_checks = 1;
-- SET SESSION unique_checks      = 1;
