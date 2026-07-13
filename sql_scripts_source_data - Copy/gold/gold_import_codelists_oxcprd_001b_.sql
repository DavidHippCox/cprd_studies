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
  PRIMARY KEY(MedCodeId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE v1_5_dementia_codes_GOLD LIKE medcode_template;
CREATE TABLE v1_alcohol_related_psychiatric_codes_GOLD LIKE medcode_template;
CREATE TABLE v1_care_home_codes_GOLD LIKE medcode_template;
CREATE TABLE v1_depression_anxiety_codes_GOLD LIKE medcode_template;
CREATE TABLE v1_drug_related_psychiatric_codes_GOLD LIKE medcode_template;
CREATE TABLE v1_neuropsychariatric_codes_GOLD LIKE medcode_template;
CREATE TABLE v1_smi_codes_GOLD LIKE medcode_template;
CREATE TABLE v1_tbi_codes_GOLD LIKE medcode_template;
CREATE TABLE v2_2_alcohol_codes_GOLD LIKE medcode_template;

ALTER TABLE v1_5_dementia_codes_GOLD
  ADD COLUMN subtype VARCHAR(255),
  ADD COLUMN early_onset VARCHAR(255),
  ADD COLUMN strict_phenotype VARCHAR(255),
  ADD COLUMN comments VARCHAR(255);

ALTER TABLE v1_neuropsychariatric_codes_GOLD
  ADD COLUMN nsp_subtype VARCHAR(255);

ALTER TABLE v2_2_alcohol_codes_GOLD
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- CREATE TABLE v0_alcohol_drug_GOLD LIKE prodcode_template;
CREATE TABLE v1_2_dementia_drug_GOLD LIKE prodcode_template;
CREATE TABLE v1_medication_codes_GOLD LIKE prodcode_template;

ALTER TABLE v1_medication_codes_GOLD
  ADD COLUMN drugtypes VARCHAR(255),
  ADD COLUMN alcohol_detoxification VARCHAR(255);



CREATE TABLE IF NOT EXISTS icd10_template (
  icd10 BIGINT UNSIGNED,
  description TEXT,
  PRIMARY KEY(icd10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE alcohol_codes_icd10 LIKE icd10_template;
CREATE TABLE dementia_codes_icd10 LIKE icd10_template;


DELIMITER //

CREATE PROCEDURE load_file(
    IN p_file VARCHAR(255),
    IN p_table VARCHAR(255)
)
BEGIN
  SET @sql = CONCAT(
    "LOAD DATA INFILE '",
    @root,
    p_file,
    "' INTO TABLE ",
    p_table,
    " FIELDS TERMINATED BY '\t'
      LINES TERMINATED BY '\r\n'
      IGNORE 1 LINES"
  );

  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
END//

DELIMITER ;


SET @root =
'{{CODELISTS_ROOT}}/codelist_tools/';

SET GLOBAL local_infile = 1;

CALL load_file('gold/readcodes/v2_2_alcohol_codes_GOLD.txt','v2_2_alcohol_codes_GOLD');
CALL load_file('gold/readcodes/v1_5_dementia_codes_GOLD.txt','v1_5_dementia_codes_GOLD');
CALL load_file('gold/readcodes/v1_alcohol_related_psychiatric_codes_GOLD.txt','v1_alcohol_related_psychiatric_codes_GOLD');
CALL load_file('gold/readcodes/v1_care_home_codes_GOLD.txt','v1_care_home_codes_GOLD');
CALL load_file('gold/readcodes/v1_depression_anxiety_codes_GOLD.txt','v1_depression_anxiety_codes_GOLD');
CALL load_file('gold/readcodes/v1_drug_related_psychiatric_codes_GOLD.txt','v1_drug_related_psychiatric_codes_GOLD');
CALL load_file('gold/readcodes/v1_neuropsychariatric_codes_GOLD.txt','v1_neuropsychariatric_codes_GOLD');
CALL load_file('gold/readcodes/v1_smi_codes_GOLD.txt','v1_smi_codes_GOLD');
CALL load_file('gold/readcodes/v1_tbi_codes_GOLD.txt','v1_tbi_codes_GOLD');


-- CALL load_file('gold/dmdcodes/v0_alcohol_drug_GOLD.txt','v0_alcohol_drug_GOLD');
CALL load_file('gold/dmdcodes/v1_2_dementia_drug_GOLD.txt','v1_2_dementia_drug_GOLD');
CALL load_file('gold/dmdcodes/v1_medication_codes_GOLD.txt','v1_medication_codes_GOLD');

call load_file('icd10/alchol_codes_icd10', 'alcohol_codes_icd10')
call load_file('icd10/dementia_codes_icd10', 'dementia_codes_icd10')