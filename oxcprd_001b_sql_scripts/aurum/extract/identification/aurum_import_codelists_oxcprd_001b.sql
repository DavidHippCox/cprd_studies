-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
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

CREATE TABLE v0_dementia_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_alcohol_related_psychiatric_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_care_home_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_depression_anxiety_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_drug_related_psychiatric_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_neuropsychiatric_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_smi_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_wenicke_encephalopathy_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_diabetes_all_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_hypertension_codes_aurum LIKE medcode_template;

CREATE TABLE v0_ihd_codes_aurum LIKE medcode_template;

CREATE TABLE v0_tbi_codes_AURUM LIKE medcode_template;

CREATE TABLE v1_arld_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_alcohol_codes_AURUM LIKE medcode_template;

CREATE TABLE v0_bmi_codes_aurum LIKE medcode_template;

CREATE TABLE v0_weight_codes_aurum LIKE medcode_template;

CREATE TABLE v0_height_codes_aurum LIKE medcode_template;

CREATE TABLE v0_smoking_codes_aurum LIKE medcode_template;

ALTER TABLE v0_dementia_codes_AURUM
ADD COLUMN subtype VARCHAR(255),
ADD COLUMN early_onset VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255),
ADD COLUMN comments VARCHAR(255);

ALTER TABLE v0_neuropsychiatric_codes_AURUM
ADD COLUMN nsp_subtype VARCHAR(255);

ALTER TABLE v0_alcohol_codes_AURUM
ADD COLUMN alc_category VARCHAR(255),
ADD COLUMN strict_phenotype VARCHAR(255),
ADD COLUMN history_of VARCHAR(255),
ADD COLUMN DHC_comments VARCHAR(255),
ADD COLUMN AT_NF_comments VARCHAR(255);

ALTER TABLE v0_smoking_codes_aurum
ADD COLUMN smokstatus VARCHAR(255),
ADD COLUMN comments VARCHAR(255);

ALTER TABLE v0_diabetes_all_codes_AURUM
ADD COLUMN category VARCHAR(255);

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

CREATE TABLE v0_alcohol_drug_AURUM LIKE prodcode_template;

CREATE TABLE v0_dementia_drug_AURUM LIKE prodcode_template;

CREATE TABLE v0_medication_codes_AURUM LIKE prodcode_template;

ALTER TABLE v0_medication_codes_AURUM
ADD COLUMN drugtypes VARCHAR(255),
ADD COLUMN alcohol_detoxification VARCHAR(255);

ALTER TABLE v0_dementia_drug_AURUM
ADD COLUMN drugtypes VARCHAR(255);

CREATE TABLE IF NOT EXISTS icd10_template (icd10 VARCHAR(255), description VARCHAR(255), PRIMARY KEY (icd10)) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

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

CALL LOAD_FILE('aurum/medcodes/v0_alcohol_codes_AURUM.txt', 'v0_alcohol_codes_AURUM');

CALL LOAD_FILE('aurum/medcodes/v0_dementia_codes_AURUM.txt', 'v0_dementia_codes_AURUM');

CALL LOAD_FILE(
  'aurum/medcodes/v0_alcohol_related_psychiatric_codes_AURUM.txt',
  'v0_alcohol_related_psychiatric_codes_AURUM'
);

CALL LOAD_FILE('aurum/medcodes/v0_care_home_codes_AURUM.txt', 'v0_care_home_codes_AURUM');

CALL LOAD_FILE(
  'aurum/medcodes/v0_depression_anxiety_codes_AURUM.txt',
  'v0_depression_anxiety_codes_AURUM'
);

CALL LOAD_FILE(
  'aurum/medcodes/v0_drug_related_psychiatric_codes_AURUM.txt',
  'v0_drug_related_psychiatric_codes_AURUM'
);

CALL LOAD_FILE(
  'aurum/medcodes/v0_neuropsychiatric_codes_AURUM.txt',
  'v0_neuropsychiatric_codes_AURUM'
);

CALL LOAD_FILE('aurum/medcodes/v0_smi_codes_AURUM.txt', 'v0_smi_codes_AURUM');

CALL LOAD_FILE(
  'aurum/medcodes/v0_wenicke_encephalopathy_codes_aurum.txt',
  'v0_wenicke_encephalopathy_codes_aurum'
);

CALL LOAD_FILE('aurum/medcodes/v0_diabetes_all_codes_AURUM.txt', 'v0_diabetes_all_codes_AURUM');

CALL LOAD_FILE('aurum/medcodes/v0_hypertension_codes_aurum.txt', 'v0_hypertension_codes_aurum');

CALL LOAD_FILE('aurum/medcodes/v0_ihd_codes_aurum.txt', 'v0_ihd_codes_aurum');

CALL LOAD_FILE('aurum/medcodes/v0_tbi_codes_AURUM.txt', 'v0_tbi_codes_AURUM');

CALL LOAD_FILE('aurum/medcodes/v1_arld_codes_AURUM.txt', 'v1_arld_codes_AURUM');

CALL LOAD_FILE('aurum/medcodes/v0_bmi_codes_AURUM.txt', 'v0_bmi_codes_AURUM');

CALL LOAD_FILE('aurum/medcodes/v0_weight_codes_AURUM.txt', 'v0_weight_codes_AURUM');

CALL LOAD_FILE('aurum/medcodes/v0_height_codes_AURUM.txt', 'v0_height_codes_AURUM');

CALL LOAD_FILE('aurum/medcodes/v0_smoking_codes_AURUM.txt', 'v0_smoking_codes_AURUM');

CALL LOAD_FILE('aurum/prodcodes/v0_alcohol_drug_AURUM.txt', 'v0_alcohol_drug_AURUM');

CALL LOAD_FILE('aurum/prodcodes/v0_dementia_drug_AURUM.txt', 'v0_dementia_drug_AURUM');

CALL LOAD_FILE('aurum/prodcodes/v0_medication_codes_AURUM.txt', 'v0_medication_codes_AURUM');

CALL LOAD_FILE('icd10/alcohol_codes_icd10.txt', 'alcohol_codes_icd10');

CALL LOAD_FILE('icd10/dementia_codes_icd10.txt', 'dementia_codes_icd10');

CREATE TABLE v0_thiamine_drug_AURUM LIKE prodcode_template;

ALTER TABLE v0_thiamine_drug_AURUM
ADD COLUMN dosage_mg SMALLINT;

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
  @dosage_mg
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
  dosage_mg = NULLIF(@dosage_mg, '');

CREATE TABLE v0_bmi_numunitid_aurum (
  medcodeid BIGINT UNSIGNED NOT NULL,
  numunitid BIGINT UNSIGNED NOT NULL,
  numunitid_description VARCHAR(255) NULL,
  conversion_rule VARCHAR(20) NOT NULL,
  PRIMARY KEY (medcodeid, numunitid)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE v0_weight_numunitid_aurum LIKE v0_bmi_numunitid_aurum;

CREATE TABLE v0_height_numunitid_aurum LIKE v0_bmi_numunitid_aurum;

CREATE TABLE v0_smoking_numunitid_aurum (
  medcodeid BIGINT UNSIGNED NOT NULL,
  term VARCHAR(999),
  numunitid BIGINT UNSIGNED NOT NULL,
  numunitid_description VARCHAR(255) NULL,
  source_smokstatus VARCHAR(30) NOT NULL,
  rule_type VARCHAR(30) NOT NULL,
  zero_status VARCHAR(30) NOT NULL,
  positive_status VARCHAR(30) NOT NULL,
  positive_upper_bound_exclusive DECIMAL(18, 6) NULL,
  PRIMARY KEY (medcodeid, numunitid)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CALL LOAD_FILE('aurum/medcodes/v0_bmi_numunitid_aurum.txt', 'v0_bmi_numunitid_aurum');

CALL LOAD_FILE('aurum/medcodes/v0_weight_numunitid_aurum.txt', 'v0_weight_numunitid_aurum');

CALL LOAD_FILE('aurum/medcodes/v0_height_numunitid_aurum.txt', 'v0_height_numunitid_aurum');

LOAD DATA INFILE '{{CODELISTS_ROOT}}/codelist_tools/aurum/medcodes/v0_smoking_numunitid_aurum.txt' INTO TABLE v0_smoking_numunitid_aurum CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\r\n' IGNORE 1 LINES (
  medcodeid,
  term,
  numunitid,
  numunitid_description,
  source_smokstatus,
  rule_type,
  zero_status,
  positive_status,
  @positive_upper_bound_exclusive
)
SET
  positive_upper_bound_exclusive = NULLIF(@positive_upper_bound_exclusive, '');