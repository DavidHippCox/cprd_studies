USE aurum_test;

-- Bulk-load settings. Run these in every MySQL session that will execute load calls.
-- Adjust buffer pool size to match your server before running if needed.
SET GLOBAL innodb_flush_log_at_trx_commit = 0;

SET SESSION foreign_key_checks = 0;
SET SESSION unique_checks      = 0;

-- ============================================================
-- Import progress table
-- ============================================================

CREATE TABLE IF NOT EXISTS aurum_import_progress (
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
  UNIQUE KEY uq_aurum_import_file (target_table, source_file),
  KEY idx_aurum_import_status (target_table, status),
  KEY idx_aurum_import_started (started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Template tables.
-- ============================================================

CREATE TABLE IF NOT EXISTS tpl_practice_raw (
  pracid MEDIUMINT, lcd DATE, uts DATE, region MEDIUMINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_staff_raw (
  staffid BIGINT NOT NULL, pracid MEDIUMINT, jobcatid MEDIUMINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_patient_raw (
  patid BIGINT UNSIGNED, pracid MEDIUMINT, usualgpstaffid BIGINT, gender SMALLINT, yob SMALLINT, mob TINYINT,
  emis_ddate DATE, regstartdate DATE, patienttypeid MEDIUMINT, regenddate DATE, acceptable BOOL, cprd_ddate DATE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_referral_raw (
  patid BIGINT UNSIGNED, obsid BIGINT UNSIGNED NOT NULL, pracid MEDIUMINT, refsourceorgid BIGINT, reftargetorgid BIGINT,
  refurgencyid TINYINT, refservicetypeid TINYINT, refmodeid TINYINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_problem_raw (
  patid BIGINT UNSIGNED, obsid BIGINT UNSIGNED NOT NULL, pracid MEDIUMINT, parentprobobsid BIGINT UNSIGNED, probenddate DATE,
  expduration MEDIUMINT, lastrevdate DATE, lastrevstaffid VARCHAR(10), parentprobrelid MEDIUMINT, probstatusid MEDIUMINT,
  signid MEDIUMINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_consultation_raw (
  patid BIGINT UNSIGNED, consid BIGINT UNSIGNED NOT NULL, pracid MEDIUMINT, consdate DATE, enterdate DATE,
  staffid BIGINT, conssourceid BIGINT, cprdconstype SMALLINT, consmedcodeid BIGINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_drugissue_raw (
  patid BIGINT UNSIGNED, issueid BIGINT UNSIGNED, pracid MEDIUMINT, probobsid BIGINT UNSIGNED, drugrecid BIGINT UNSIGNED,
  issuedate DATE, enterdate DATE, staffid BIGINT, prodcodeid BIGINT, dosageid CHAR(64),
  quantity DECIMAL(9,3), quantunitid TINYINT, duration BIGINT, estnhscost DECIMAL(10,4)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tpl_observation_raw (
  patid BIGINT UNSIGNED, consid BIGINT UNSIGNED, pracid MEDIUMINT, obsid BIGINT UNSIGNED NOT NULL, obsdate DATE, enterdate DATE,
  staffid BIGINT, parentsobsid BIGINT UNSIGNED, medcodeid BIGINT, value DECIMAL(19,3), numunitid BIGINT, obstypeid MEDIUMINT,
  numrangelow DECIMAL(19,3), numrangehigh DECIMAL(19,3), probobsid BIGINT UNSIGNED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Import tables
-- ============================================================

CREATE TABLE IF NOT EXISTS practice LIKE tpl_practice_raw;
CREATE TABLE IF NOT EXISTS staff LIKE tpl_staff_raw;
CREATE TABLE IF NOT EXISTS patient LIKE tpl_patient_raw;
CREATE TABLE IF NOT EXISTS referral LIKE tpl_referral_raw;
CREATE TABLE IF NOT EXISTS problem LIKE tpl_problem_raw;

CREATE TABLE IF NOT EXISTS consultation_001 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_002 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_003 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_004 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_005 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_006 LIKE tpl_consultation_raw;
CREATE TABLE IF NOT EXISTS consultation_007 LIKE tpl_consultation_raw;


CREATE TABLE IF NOT EXISTS drugissue_001 LIKE tpl_drugissue_raw;
CREATE TABLE IF NOT EXISTS drugissue_002 LIKE tpl_drugissue_raw;
CREATE TABLE IF NOT EXISTS drugissue_003 LIKE tpl_drugissue_raw;
CREATE TABLE IF NOT EXISTS drugissue_004 LIKE tpl_drugissue_raw;
CREATE TABLE IF NOT EXISTS drugissue_005 LIKE tpl_drugissue_raw;
CREATE TABLE IF NOT EXISTS drugissue_006 LIKE tpl_drugissue_raw;
CREATE TABLE IF NOT EXISTS drugissue_007 LIKE tpl_drugissue_raw;
CREATE TABLE IF NOT EXISTS drugissue_008 LIKE tpl_drugissue_raw;


CREATE TABLE IF NOT EXISTS observation_001 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_002 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_003 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_004 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_005 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_006 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_007 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_008 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_009 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_010 LIKE tpl_observation_raw;

CREATE TABLE IF NOT EXISTS observation_011 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_012 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_013 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_014 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_015 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_016 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_017 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_018 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_019 LIKE tpl_observation_raw;
CREATE TABLE IF NOT EXISTS observation_020 LIKE tpl_observation_raw;

-- ============================================================
-- Procedures
-- ============================================================

DROP PROCEDURE IF EXISTS load_aurum_file_raw;
DROP PROCEDURE IF EXISTS load_aurum_range_raw;
DROP PROCEDURE IF EXISTS aurum_import_summary;

DELIMITER $$

CREATE PROCEDURE load_aurum_file_raw(
  IN p_target_table VARCHAR(64),
  IN p_file_type VARCHAR(64),
  IN p_source_folder VARCHAR(64),
  IN p_file_no INT UNSIGNED
)
proc: BEGIN
  DECLARE v_root VARCHAR(1024) DEFAULT '{{DATA_ROOT}}/Aurum_SEP2024';
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

    UPDATE aurum_import_progress
       SET status = 'failed',
           finished_at = NOW(),
           mysql_errno = v_errno,
           message = v_message
     WHERE target_table = p_target_table
       AND source_file = v_source_file;

    RESIGNAL;
  END;

  SET v_file_type_norm = LOWER(p_file_type);
  SET v_file_prefix = CASE
    WHEN v_file_type_norm = 'drugissue' THEN 'drugIssue'
    ELSE p_file_type
  END;

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
    FROM aurum_import_progress
   WHERE target_table = p_target_table
     AND source_file = v_source_file
     AND status = 'success';

  IF v_already_done > 0 THEN
    LEAVE proc;
  END IF;

  INSERT INTO aurum_import_progress
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
    SET v_columns = '(@patid, @consid, @pracid, @obsid, @obsdate, @enterdate, @staffid, @parentsobsid, @medcodeid, @value, @numunitid, @obstypeid, @numrangelow, @numrangehigh, @probobsid)';
    SET v_set_clause = 'patid = NULLIF(@patid, ''''), consid = NULLIF(@consid, ''''), pracid = NULLIF(@pracid, ''''), obsid = NULLIF(@obsid, ''''), obsdate = NULLIF(@obsdate, ''''), enterdate = NULLIF(@enterdate, ''''), staffid = NULLIF(@staffid, ''''), parentsobsid = NULLIF(@parentsobsid, ''''), medcodeid = NULLIF(@medcodeid, ''''), value = NULLIF(@value, ''''), numunitid = NULLIF(@numunitid, ''''), obstypeid = NULLIF(@obstypeid, ''''), numrangelow = NULLIF(@numrangelow, ''''), numrangehigh = NULLIF(@numrangehigh, ''''), probobsid = NULLIF(@probobsid, '''')';
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
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown file type passed to load_aurum_file_raw';
  END IF;

  SET @load_sql = CONCAT(
    'LOAD DATA INFILE ', QUOTE(v_source_path), ' IGNORE ',
    'INTO TABLE aurum_test.', v_target_table_sql, ' ',
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

  UPDATE aurum_import_progress
     SET status = 'success',
         finished_at = NOW(),
         rows_loaded = v_rows,
         mysql_errno = NULL,
         message = 'Imported successfully'
   WHERE target_table = p_target_table
     AND source_file = v_source_file;
END$$

CREATE PROCEDURE load_aurum_range_raw(
  IN p_target_table VARCHAR(64),
  IN p_file_type VARCHAR(64),
  IN p_source_folder VARCHAR(64),
  IN p_first_file INT UNSIGNED,
  IN p_last_file INT UNSIGNED
)
BEGIN
  DECLARE i INT UNSIGNED;

  SET i = p_first_file;
  WHILE i <= p_last_file DO
    CALL load_aurum_file_raw(p_target_table, p_file_type, p_source_folder, i);
    SET i = i + 1;
  END WHILE;
END$$

CREATE PROCEDURE aurum_import_summary()
BEGIN
  SELECT target_table,
         COUNT(*) AS files_attempted,
         SUM(status = 'success') AS files_success,
         SUM(status = 'failed') AS files_failed,
         SUM(rows_loaded) AS rows_loaded,
         MIN(started_at) AS first_started_at,
         MAX(finished_at) AS last_finished_at
    FROM aurum_import_progress
   GROUP BY target_table
   ORDER BY target_table;
END$$

DELIMITER ;

-- ============================================================

-- ============================================================

-- CALL aurum_import_summary();

-- Restore durability after all bulk loads are complete:
-- SET GLOBAL innodb_flush_log_at_trx_commit = 1;
-- SET SESSION foreign_key_checks = 1;
-- SET SESSION unique_checks      = 1;
