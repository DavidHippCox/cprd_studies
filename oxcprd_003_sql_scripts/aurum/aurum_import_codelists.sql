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
ADD COLUMN AT_NF_comments VARCHAR(255);

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

/*
CREATE TABLE alcohol_codes_icd10 LIKE icd10_template;

ALTER TABLE alcohol_codes_icd10
ADD COLUMN alc_category VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255);

*/
DELIMITER $$
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

END $$ DELIMITER;

SET
  @root = '{{CODELISTS_ROOT}}/codelist_tools/';

SET
  GLOBAL local_infile = 1;

CALL LOAD_FILE('aurum/medcodes/v0_alcohol_codes_AURUM.txt', 'v0_alcohol_codes_AURUM');

-- call load_file('icd10/alcohol_codes_icd10.txt', 'alcohol_codes_icd10');
CREATE TABLE v0_thiamine_drug_AURUM LIKE prodcode_template;

ALTER TABLE v0_thiamine_drug_AURUM
ADD COLUMN DHC_review VARCHAR(255),
ADD COLUMN dosage_mg SMALLINT,
ADD COLUMN exclude_patid_if_within_thimaine_monotherapy_window TINYINT;

LOAD DATA INFILE '{{CODELISTS_ROOT}}/codelist_tools/aurum/prodcodes/v0_thiamine_drug_AURUM.txt' INTO TABLE v0_thiamine_drug_AURUM FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\r\n' IGNORE 1 LINES (
  @prodcodeid,
  @dmdid,
  @termfromemis,
  @productname,
  @formulation,
  @routeofadministration,
  @drugsubstancename,
  @substancestrength,
  @bnfchapter,
  @drugissues,
  @DHC_review,
  @dosage_mg,
  @exclude_patid_if_within_thimaine_monotherapy_window
)
SET
  prodcodeid = NULLIF(@prodcodeid, ''),
  dmdid = NULLIF(@dmdid, ''),
  termfromemis = NULLIF(@termfromemis, ''),
  productname = NULLIF(@productname, ''),
  formulation = NULLIF(@formulation, ''),
  routeofadministration = NULLIF(@routeofadministration, ''),
  drugsubstancename = NULLIF(@drugsubstancename, ''),
  substancestrength = NULLIF(@substancestrength, ''),
  bnfchapter = NULLIF(@bnfchapter, ''),
  DHC_review = NULLIF(@DHC_review, ''),
  dosage_mg = NULLIF(@dosage_mg, ''),
  exclude_patid_if_within_thimaine_monotherapy_window = NULLIF(@exclude_patid_if_within_thimaine_monotherapy_window, '');
