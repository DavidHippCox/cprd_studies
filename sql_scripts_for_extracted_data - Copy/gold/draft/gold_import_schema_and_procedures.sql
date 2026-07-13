USE gold_test;

-- Derived pracid for patient-linked tables uses the last 5 digits of patid,

-- ~ 64 GB buffer pool
SET GLOBAL innodb_buffer_pool_size        = 68719476736;

-- No flush to disk on every commit: safe for bulk load, restore after
SET GLOBAL innodb_flush_log_at_trx_commit = 0;

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
  sctisindicative TINYINT,
  sctisassured TINYINT,
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
  sctisindicative TINYINT,
  sctisassured TINYINT,
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
  sctisindicative TINYINT,
  sctisassured TINYINT,
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
  sctisindicative TINYINT,
  sctisassured TINYINT,
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
  qty BIGINT UNSIGNED,
  numdays INT UNSIGNED,
  numpacks INT UNSIGNED,
  packtype INT UNSIGNED,
  issueseq BIGINT UNSIGNED,
  prn TINYINT

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_medical_dictionary_raw (
  medcode INT UNSIGNED,
  readcode TEXT,
  `desc` TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_product_dictionary_raw (
  prodcode INT UNSIGNED,
  dmdcode TEXT,
  gemscriptcode TEXT,
  productname TEXT,
  drugsubstance TEXT,
  strength TEXT,
  formulation TEXT,
  route TEXT,
  bnfcode TEXT,
  bnfchapter TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Import tables
-- ============================================================

CREATE TABLE IF NOT EXISTS practice_raw LIKE tpl_practice_raw;
CREATE TABLE IF NOT EXISTS staff_raw LIKE tpl_staff_raw;
CREATE TABLE IF NOT EXISTS patient_raw LIKE tpl_patient_raw;
CREATE TABLE IF NOT EXISTS referral_raw LIKE tpl_referral_raw;

CREATE TABLE IF NOT EXISTS consultation_001 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_002 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_003 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_004 LIKE tpl_consultation_raw;

CREATE TABLE IF NOT EXISTS clinical_raw LIKE tpl_clinical_raw;

CREATE TABLE IF NOT EXISTS additional_raw LIKE tpl_additional_raw;

CREATE TABLE IF NOT EXISTS immunisation_raw LIKE tpl_immunisation_raw;

CREATE TABLE IF NOT EXISTS test_001 LIKE tpl_test_raw;
CREATE TABLE IF NOT EXISTS test_002 LIKE tpl_test_raw;

CREATE TABLE IF NOT EXISTS therapy_001 LIKE tpl_therapy_raw;
CREATE TABLE IF NOT EXISTS therapy_002 LIKE tpl_therapy_raw;
CREATE TABLE IF NOT EXISTS therapy_003 LIKE tpl_therapy_raw;

CREATE TABLE IF NOT EXISTS medical_dictionary_raw LIKE tpl_medical_dictionary_raw;
CREATE TABLE IF NOT EXISTS product_dictionary_raw LIKE tpl_product_dictionary_raw;

-- ============================================================
-- Procedures
-- ============================================================

DROP PROCEDURE IF EXISTS load_gold_file_raw;
DROP PROCEDURE IF EXISTS load_gold_range_raw;
DROP PROCEDURE IF EXISTS gold_import_summary;

DELIMITER $$

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

  IF v_file_type_norm = 'consultation' THEN
    SET v_columns = '(@patid, @consid, @pracid, @consdate, @enterdate, @staffid, @conssourceid, @cprdconstype, @consmedcodeid)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), consid = NULLIF(@consid, ''''), pracid = NULLIF(@pracid, ''''), consdate = NULLIF(@consdate, ''''), enterdate = NULLIF(@enterdate, ''''), staffid = NULLIF(@staffid, ''''), conssourceid = NULLIF(@conssourceid, ''''), cprdconstype = NULLIF(@cprdconstype, ''''), consmedcodeid = NULLIF(@consmedcodeid, '''')';
  ELSEIF v_file_type_norm = 'drugissue' THEN
    SET v_columns = '(@patid, @issueid, @pracid, @probobsid, @drugrecid, @issuedate, @enterdate, @staffid, @prodcodeid, @dosageid, @quantity, @quantunitid, @duration, @estnhscost)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), issueid = NULLIF(@issueid, ''''), pracid = NULLIF(@pracid, ''''), probobsid = NULLIF(@probobsid, ''''), drugrecid = NULLIF(@drugrecid, ''''), issuedate = NULLIF(@issuedate, ''''), enterdate = NULLIF(@enterdate, ''''), staffid = NULLIF(@staffid, ''''), prodcodeid = NULLIF(@prodcodeid, ''''), dosageid = NULLIF(@dosageid, ''''), quantity = NULLIF(@quantity, ''''), quantunitid = NULLIF(@quantunitid, ''''), duration = NULLIF(@duration, ''''), estnhscost = NULLIF(@estnhscost, '''')';
  ELSEIF v_file_type_norm = 'observation' THEN
    SET v_columns = '(@patid, @consid, @pracid, @obsid, @obsdate, @enterdate, @staffid, @parentsobsid, @medcodeid, @testvalue, @numunitid, @obstypeid, @numrangelow, @numrangehigh, @probobsid)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), consid = NULLIF(@consid, ''''), pracid = NULLIF(@pracid, ''''), obsid = NULLIF(@obsid, ''''), obsdate = NULLIF(@obsdate, ''''), enterdate = NULLIF(@enterdate, ''''), staffid = NULLIF(@staffid, ''''), parentsobsid = NULLIF(@parentsobsid, ''''), medcodeid = NULLIF(@medcodeid, ''''), testvalue = NULLIF(@testvalue, ''''), numunitid = NULLIF(@numunitid, ''''), obstypeid = NULLIF(@obstypeid, ''''), numrangelow = NULLIF(@numrangelow, ''''), numrangehigh = NULLIF(@numrangehigh, ''''), probobsid = NULLIF(@probobsid, '''')';
  ELSEIF v_file_type_norm = 'patient' THEN
    SET v_columns = '(@patid, @pracid, @usualgpstaffid, @gender, @yob, @mob, @emis_ddate, @regstartdate, @patienttypeid, @regenddate, @acceptable, @cprd_ddate)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), pracid = NULLIF(@pracid, ''''), usualgpstaffid = NULLIF(@usualgpstaffid, ''''), gender = NULLIF(@gender, ''''), yob = NULLIF(@yob, ''''), mob = NULLIF(@mob, ''''), emis_ddate = NULLIF(@emis_ddate, ''''), regstartdate = NULLIF(@regstartdate, ''''), patienttypeid = NULLIF(@patienttypeid, ''''), regenddate = NULLIF(@regenddate, ''''), acceptable = NULLIF(@acceptable, ''''), cprd_ddate = NULLIF(@cprd_ddate, '''')';
  ELSEIF v_file_type_norm = 'practice' THEN
    SET v_columns = '(@pracid, @lcd, @uts, @region)';
    SET v_set_clause = 'pracid = NULLIF(@pracid, ''''), lcd = NULLIF(@lcd, ''''), uts = NULLIF(@uts, ''''), region = NULLIF(@region, '''')';
  ELSEIF v_file_type_norm = 'problem' THEN
    SET v_columns = '(@patid, @obsid, @pracid, @parentprobobsid, @probenddate, @expduration, @lastrevdate, @lastrevstaffid, @parentprobrelid, @probstatusid, @signid)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), obsid = NULLIF(@obsid, ''''), pracid = NULLIF(@pracid, ''''), parentprobobsid = NULLIF(@parentprobobsid, ''''), probenddate = NULLIF(@probenddate, ''''), expduration = NULLIF(@expduration, ''''), lastrevdate = NULLIF(@lastrevdate, ''''), lastrevstaffid = NULLIF(@lastrevstaffid, ''''), parentprobrelid = NULLIF(@parentprobrelid, ''''), probstatusid = NULLIF(@probstatusid, ''''), signid = NULLIF(@signid, '''')';
  ELSEIF v_file_type_norm = 'referral' THEN
    SET v_columns = '(@patid, @obsid, @pracid, @refsourceorgid, @reftargetorgid, @refurgencyid, @refservicetypeid, @refmodeid)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), obsid = NULLIF(@obsid, ''''), pracid = NULLIF(@pracid, ''''), refsourceorgid = NULLIF(@refsourceorgid, ''''), reftargetorgid = NULLIF(@reftargetorgid, ''''), refurgencyid = NULLIF(@refurgencyid, ''''), refservicetypeid = NULLIF(@refservicetypeid, ''''), refmodeid = NULLIF(@refmodeid, '''')';
  ELSEIF v_file_type_norm = 'staff' THEN
    SET v_columns = '(@staffid, @pracid, @jobcatid)';
    SET v_set_clause = 'staffid = NULLIF(@staffid, ''''), pracid = NULLIF(@pracid, ''''), jobcatid = NULLIF(@jobcatid, '''')';
  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown file type passed to load_gold_file_raw';
  END IF;

  SET @load_sql = CONCAT(
    'LOAD DATA INFILE ', QUOTE(v_source_path), ' IGNORE ',
    'INTO TABLE gold_test.', v_target_table_sql, ' ',
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

DELIMITER ;

-- ============================================================

-- ============================================================

-- CALL gold_import_summary();

-- Restore durability after all bulk loads are complete:
-- SET GLOBAL innodb_flush_log_at_trx_commit = 1;
-- SET SESSION foreign_key_checks = 1;
-- SET SESSION unique_checks      = 1;
