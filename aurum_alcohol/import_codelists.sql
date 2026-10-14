-- import codelists
USE aurum_alcohol;

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

CREATE TABLE v0_alcohol_codes_AURUM LIKE medcode_template;

ALTER TABLE v0_alcohol_codes_AURUM
ADD COLUMN alc_category VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255),
ADD COLUMN history_of VARCHAR(255),
ADD COLUMN DHC_comments VARCHAR(255),
ADD COLUMN AT_NF_comments VARCHAR(255)
ADD PRIMARY KEY (medcodeid);

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

CREATE TABLE alcohol_codes_icd10 LIKE icd10_template;

ALTER TABLE alcohol_codes_icd10
ADD COLUMN alc_category VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255)
ADD PRIMARY KEY (icd10);

/* sql-formatter-disable */
DELIMITER //
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

CALL LOAD_FILE('aurum/prodcodes/v0_alcohol_drug_AURUM.txt', 'v0_alcohol_drug_AURUM');

CALL LOAD_FILE('icd10/alcohol_codes_icd10.txt', 'alcohol_codes_icd10');

-- alcohol unit medcodeid and numunitid looksups
CREATE TABLE IF NOT EXISTS aurum_alcohol.alcohol_unit_aurum (
  medcodeid BIGINT UNSIGNED NOT NULL,
  observations VARCHAR(500) NOT NULL,
  term VARCHAR(500) NOT NULL,
  term_has_unit TINYINT(1) NOT NULL,
  term_period VARCHAR(10) NULL,
  zero_allowed TINYINT(1) NOT NULL,
  PRIMARY KEY (medcodeid)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

LOAD DATA INFILE '{{CODELISTS_ROOT}}/codelist_tools/aurum/medcodes/v0_alcohol_unit_aurum.txt' IGNORE INTO TABLE alcohol_unit_aurum FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\r\n' IGNORE 1 LINES (medcodeid, @observations, @term, @term_has_unit, @term_period, @zero_allowed)
SET
  term = NULLIF(@term, ''),
  observations = NULLIF(@observations, ''),
  term_has_unit = NULLIF(@term_has_unit, ''),
  term_period = NULLIF(@term_period, ''),
  zero_allowed = NULLIF(@zero_allowed, '');

CREATE TABLE IF NOT EXISTS aurum_alcohol.alcohol_unit_numunitid_aurum (
  numunitid BIGINT UNSIGNED NOT NULL,
  description VARCHAR(500) NOT NULL,
  amount_type VARCHAR(10) NOT NULL,
  amount_low DECIMAL(19, 3) NULL,
  amount_high DECIMAL(19, 3) NULL,
  numunit_has_unit TINYINT(1) NOT NULL,
  numunit_period VARCHAR(10) NULL,
  weekly_multiplier DECIMAL(20, 15) NULL,
  PRIMARY KEY (numunitid)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

LOAD DATA INFILE '{{CODELISTS_ROOT}}/codelist_tools/aurum/medcodes/v0_alcohol_unit_numunitid_aurum.txt' IGNORE INTO TABLE alcohol_unit_numunitid_aurum FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\r\n' IGNORE 1 LINES (
  numunitid,
  @description,
  @amount_type,
  @amount_low,
  @amount_high,
  @numunit_has_unit,
  @numunit_period,
  @weekly_multiplier
)
SET
  description = NULLIF(@description, ''),
  amount_type = NULLIF(@amount_type, ''),
  amount_low = NULLIF(@amount_low, ''),
  amount_high = NULLIF(@amount_high, ''),
  numunit_has_unit = NULLIF(@numunit_has_unit, ''),
  numunit_period = NULLIF(@numunit_period, ''),
  weekly_multiplier = NULLIF(@weekly_multiplier, '');