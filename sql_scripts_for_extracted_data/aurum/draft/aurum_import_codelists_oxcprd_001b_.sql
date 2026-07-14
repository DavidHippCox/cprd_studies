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

CREATE TABLE v0_dementia_codes_AURUM LIKE medcode_template;
CREATE TABLE v0_alcohol_related_psychiatric_codes_AURUM LIKE medcode_template;
CREATE TABLE v0_care_home_codes_AURUM LIKE medcode_template;
CREATE TABLE v0_depression_anxiety_codes_AURUM LIKE medcode_template;
CREATE TABLE v0_drug_related_psychiatric_codes_AURUM LIKE medcode_template;
CREATE TABLE v0_neuropsychariatric_codes_AURUM LIKE medcode_template;
CREATE TABLE v0_smi_codes_AURUM LIKE medcode_template;
CREATE TABLE v0_tbi_codes_AURUM LIKE medcode_template;
CREATE TABLE v0_alcohol_codes_AURUM LIKE medcode_template;

ALTER TABLE v0_dementia_codes_AURUM
  ADD COLUMN subtype VARCHAR(255),
  ADD COLUMN early_onset VARCHAR(255),
  ADD COLUMN strict_phenotype VARCHAR(255),
  ADD COLUMN comments VARCHAR(255);

ALTER TABLE v0_neuropsychariatric_codes_AURUM
  ADD COLUMN nsp_subtype VARCHAR(255);

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE v0_alcohol_drug_AURUM LIKE prodcode_template;
CREATE TABLE v0_dementia_drug_AURUM LIKE prodcode_template;
CREATE TABLE v0_medication_codes_AURUM LIKE prodcode_template;

ALTER TABLE v0_medication_codes_AURUM
  ADD COLUMN drugtypes VARCHAR(255),
  ADD COLUMN alcohol_detoxification VARCHAR(255);

CREATE TABLE IF NOT EXISTS icd10_template (
  icd10 VARCHAR(9) NOT NULL,
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
'{{CODELISTS_ROOT}}/codelist_tools/aurum/';

SET GLOBAL local_infile = 1;

CALL load_file('medcodes/v0_alcohol_codes_AURUM.txt','v0_alcohol_codes_AURUM');
CALL load_file('medcodes/v0_dementia_codes_AURUM.txt','v0_dementia_codes_AURUM');
CALL load_file('medcodes/v0_alcohol_related_psychiatric_codes_AURUM.txt','v0_alcohol_related_psychiatric_codes_AURUM');
CALL load_file('medcodes/v0_care_home_codes_AURUM.txt','v0_care_home_codes_AURUM');
CALL load_file('medcodes/v0_depression_anxiety_codes_AURUM.txt','v0_depression_anxiety_codes_AURUM');
CALL load_file('medcodes/v0_drug_related_psychiatric_codes_AURUM.txt','v0_drug_related_psychiatric_codes_AURUM');
CALL load_file('medcodes/v0_neuropsychariatric_codes_AURUM.txt','v0_neuropsychariatric_codes_AURUM');
CALL load_file('medcodes/v0_smi_codes_AURUM.txt','v0_smi_codes_AURUM');
CALL load_file('medcodes/v0_tbi_codes_AURUM.txt','v0_tbi_codes_AURUM');


CALL load_file('prodcodes/v0_alcohol_drug_AURUM.txt','v0_alcohol_drug_AURUM');
CALL load_file('prodcodes/v0_dementia_drug_AURUM.txt','v0_dementia_drug_AURUM');
CALL load_file('prodcodes/v0_medication_codes_AURUM.txt','v0_medication_codes_AURUM');

call load_file('icd10/alchol_codes_icd10', 'alcohol_codes_icd10')
call load_file('icd10/dementia_codes_icd10', 'dementia_codes_icd10')