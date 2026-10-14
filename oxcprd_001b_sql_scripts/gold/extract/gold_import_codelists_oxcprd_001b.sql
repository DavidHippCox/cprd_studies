USE gold_oxcprd_001b;

CREATE TABLE IF NOT EXISTS medcode_template (
  medcode BIGINT UNSIGNED,
  readcode TEXT,
  clinicalevents TEXT,
  immunisationevents TEXT,
  referralevents TEXT,
  testevents TEXT,
  readterm TEXT,
  databaserelease TEXT,
  PRIMARY KEY (medcode)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE v1_5_dementia_codes_GOLD LIKE medcode_template;

CREATE TABLE v1_alcohol_related_psychiatric_codes_GOLD LIKE medcode_template;

CREATE TABLE v1_care_home_codes_GOLD LIKE medcode_template;

CREATE TABLE v1_depression_anxiety_codes_GOLD LIKE medcode_template;

CREATE TABLE v1_drug_related_psychiatric_codes_GOLD LIKE medcode_template;

CREATE TABLE v1_neuropsychiatric_codes_GOLD LIKE medcode_template;

CREATE TABLE v1_smi_codes_GOLD LIKE medcode_template;

CREATE TABLE v1_tbi_codes_GOLD LIKE medcode_template;

CREATE TABLE v2_2_alcohol_codes_GOLD LIKE medcode_template;

ALTER TABLE v1_5_dementia_codes_GOLD
ADD COLUMN subtype VARCHAR(255),
ADD COLUMN early_onset VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255),
ADD COLUMN comments VARCHAR(255);

ALTER TABLE v1_neuropsychiatric_codes_GOLD
ADD COLUMN nsp_subtype VARCHAR(255);

ALTER TABLE v2_2_alcohol_codes_GOLD
ADD COLUMN alc_category VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255);

CREATE TABLE IF NOT EXISTS prodcode_template (
  prodcode BIGINT UNSIGNED,
  dmdcode BIGINT UNSIGNED,
  gemscriptcode BIGINT UNSIGNED,
  therapyevents VARCHAR(255),
  productname VARCHAR(999),
  drugsubstance VARCHAR(999),
  strength VARCHAR(999),
  formulation VARCHAR(999),
  route VARCHAR(999),
  bnfcode VARCHAR(999),
  bnfchapter VARCHAR(999),
  databaserelease TEXT,
  PRIMARY KEY (prodcode)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- CREATE TABLE v0_alcohol_drug_GOLD LIKE prodcode_template;
CREATE TABLE v1_2_dementia_drug_GOLD LIKE prodcode_template;

CREATE TABLE v1_medication_codes_GOLD LIKE prodcode_template;

ALTER TABLE v1_medication_codes_GOLD
ADD COLUMN drugtypes VARCHAR(255),
ADD COLUMN alcohol_detoxification VARCHAR(255);

CREATE TABLE IF NOT EXISTS icd10_template (icd10 VARCHAR(9) NOT NULL, description TEXT, PRIMARY KEY (icd10)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE alcohol_codes_icd10 LIKE icd10_template;

CREATE TABLE dementia_codes_icd10 LIKE icd10_template;

ALTER TABLE alcohol_codes_icd10
ADD COLUMN alc_category VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255);

ALTER TABLE dementia_codes_icd10
ADD COLUMN subtype VARCHAR(255),
ADD COLUMN aud VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255);

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

END $$ /* sql-formatter-disable */
DELIMITER ;
/* sql-formatter-enable */
SET
  @root = '{{CODELISTS_ROOT}}/codelist_tools/';

SET
  GLOBAL local_infile = 1;

CALL LOAD_FILE('gold/readcodes/v2_2_alcohol_codes_GOLD.txt', 'v2_2_alcohol_codes_GOLD');

CALL LOAD_FILE('gold/readcodes/v1_5_dementia_codes_GOLD.txt', 'v1_5_dementia_codes_GOLD');

CALL LOAD_FILE(
  'gold/readcodes/v1_alcohol_related_psychiatric_codes_GOLD.txt',
  'v1_alcohol_related_psychiatric_codes_GOLD'
);

CALL LOAD_FILE('gold/readcodes/v1_care_home_codes_GOLD.txt', 'v1_care_home_codes_GOLD');

CALL LOAD_FILE(
  'gold/readcodes/v1_depression_anxiety_codes_GOLD.txt',
  'v1_depression_anxiety_codes_GOLD'
);

CALL LOAD_FILE(
  'gold/readcodes/v1_drug_related_psychiatric_codes_GOLD.txt',
  'v1_drug_related_psychiatric_codes_GOLD'
);

CALL LOAD_FILE(
  'gold/readcodes/v1_neuropsychiatric_codes_GOLD.txt',
  'v1_neuropsychiatric_codes_GOLD'
);

CALL LOAD_FILE('gold/readcodes/v1_smi_codes_GOLD.txt', 'v1_smi_codes_GOLD');

CALL LOAD_FILE('gold/readcodes/v1_tbi_codes_GOLD.txt', 'v1_tbi_codes_GOLD');

-- CALL load_file('gold/dmdcodes/v0_alcohol_drug_GOLD.txt','v0_alcohol_drug_GOLD');
CALL LOAD_FILE('gold/dmdcodes/v1_2_dementia_drug_GOLD.txt', 'v1_2_dementia_drug_GOLD');

CALL LOAD_FILE('gold/dmdcodes/v1_medication_codes_GOLD.txt', 'v1_medication_codes_GOLD');

CALL LOAD_FILE('icd10/alchol_codes_icd10', 'alcohol_codes_icd10')
CALL LOAD_FILE('icd10/dementia_codes_icd10', 'dementia_codes_icd10')