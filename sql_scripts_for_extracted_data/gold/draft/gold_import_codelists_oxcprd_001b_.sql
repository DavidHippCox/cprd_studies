CREATE TABLE IF NOT EXISTS medcode_template (
  medcode INT UNSIGNED,
  readcode TEXT,
  clinicalevents TEXT,
  immunisationevents TEXT,
  referralevents TEXT,
  testevents TEXT,
  readterm TEXT,
  databaserelease TEXT,
  PRIMARY KEY(medcode)
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
  ADD COLUMN strict_phenotype VARCHAR(255);



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
'{{CODELISTS_ROOT}}/codelist_tools/gold/readcodes/';

SET GLOBAL local_infile = 1;

CALL load_file('v2_2_alcohol_codes_GOLD.txt','v2_2_alcohol_codes_GOLD');
CALL load_file('v1_5_dementia_codes_GOLD.txt','v1_5_dementia_codes_GOLD');
CALL load_file('v1_alcohol_related_psychiatric_codes_GOLD.txt','v1_alcohol_related_psychiatric_codes_GOLD');
CALL load_file('v1_care_home_codes_GOLD.txt','v1_care_home_codes_GOLD');
CALL load_file('v1_depression_anxiety_codes_GOLD.txt','v1_depression_anxiety_codes_GOLD');
CALL load_file('v1_drug_related_psychiatric_codes_GOLD.txt','v1_drug_related_psychiatric_codes_GOLD');
CALL load_file('v1_neuropsychariatric_codes_GOLD.txt','v1_neuropsychariatric_codes_GOLD');
CALL load_file('v1_smi_codes_GOLD.txt','v1_smi_codes_GOLD');
CALL load_file('v1_tbi_codes_GOLD.txt','v1_tbi_codes_GOLD');