-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_002
-- analysis plan version: NA
-- import codelists
USE aurum_arld;

CREATE TABLE IF NOT EXISTS medcode_template (
  MedCodeId BIGINT UNSIGNED,
  Observations TEXT,
  OriginalReadCode TEXT,
  CleansedReadCode TEXT,
  Term TEXT,
  SnomedCTConceptId BIGINT UNSIGNED,
  SnomedCTDescriptionId BIGINT UNSIGNED,
  databaserelease TEXT,
  EmisCodeCategoryId TINYINT,
  PRIMARY KEY (MedCodeId)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE v1_arld_codes_AURUM LIKE medcode_template;

CREATE TABLE IF NOT EXISTS prodcode_template (
  prodcodeid BIGINT,
  dmdid BIGINT UNSIGNED,
  termfromemis VARCHAR(255),
  productname VARCHAR(999),
  formulation VARCHAR(999),
  routeofadministration VARCHAR(999),
  drugsubstancename VARCHAR(999),
  substancestrength VARCHAR(999),
  bnfchapter VARCHAR(999),
  drugissues TEXT,
  PRIMARY KEY (prodcodeid)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS icd10_template (icd10 VARCHAR(255), description VARCHAR(255), PRIMARY KEY (icd10)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* sql-formatter-disable */
DELIMITER $$
/* sql-formatter-enable */
CREATE PROCEDURE LOAD_FILE(IN p_file VARCHAR(255), IN p_table VARCHAR(255))
BEGIN
SET
  @sql = CONCAT(
    "LOAD DATA INFILE '",
    @root,
    p_file,
    "' INTO TABLE ",
    p_table,
    " FIELDS TERMINATED BY '\t'
      LINES TERMINATED BY '\r\n'
      IGNORE 1 LINES"
  );

PREPARE stmt
FROM
  @sql;

EXECUTE stmt;

DEALLOCATE PREPARE stmt;

END / / /* sql-formatter-disable */
DELIMITER ;
/* sql-formatter-enable */
SET
  @root = '{{CODELISTS_ROOT}}/codelist_tools/';

SET
  GLOBAL local_infile = 1;

CALL LOAD_FILE('aurum/medcodes/v1_arld_codes_AURUM.txt', 'v1_arld_codes_AURUM');
