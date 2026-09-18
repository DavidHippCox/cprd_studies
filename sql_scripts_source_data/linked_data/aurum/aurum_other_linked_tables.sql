--  linkage_eligibility:

DROP TABLE IF EXISTS linkage_eligibility

CREATE TABLE IF NOT EXISTS linkage_eligibility
(patid bigint(20) DEFAULT NULL,
  pracid bigint(20) DEFAULT NULL,
  linkyear int(11) DEFAULT NULL,
  hes_apc_e tinyint(4) DEFAULT NULL,
  ons_death_e tinyint(4) DEFAULT NULL,
  lsoa_e tinyint(4) DEFAULT NULL,
  sgss_e tinyint(4) DEFAULT NULL,
  chess_e tinyint(4) DEFAULT NULL,
  hes_op_e tinyint(4) DEFAULT NULL,
  hes_ae_e tinyint(4) DEFAULT NULL,
  hes_did_e tinyint(4) DEFAULT NULL,
  cr_e tinyint(4) DEFAULT NULL,
  sact_e tinyint(4) DEFAULT NULL,
  rtds_e tinyint(4) DEFAULT NULL,
  bsa_dispensing_e tinyint(4) DEFAULT NULL
)
ENGINE=InnoDB
CHARSET=utf8mb4

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_1/24_004516_linkage_eligibility_aurum.txt'
IGNORE
INTO TABLE linkage_eligibility
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@patid, @pracid, @linkyear, @hes_apc_e, @ons_death_e, @lsoa_e, @sgss_e, @chess_e,
 @hes_op_e, @hes_ae_e, @hes_did_e, @cr_e, @sact_e, @rtds_e, @bsa_dispensing_e)
SET
  patid = NULLIF(@patid, ''),
  pracid = NULLIF(@pracid, ''),
  linkyear = NULLIF(@linkyear, ''),
  hes_apc_e = NULLIF(@hes_apc_e, ''),
  ons_death_e = NULLIF(@ons_death_e, ''),
  lsoa_e = NULLIF(@lsoa_e, ''),
  sgss_e = NULLIF(@sgss_e, ''),
  chess_e = NULLIF(@chess_e, ''),
  hes_op_e = NULLIF(@hes_op_e, ''),
  hes_ae_e = NULLIF(@hes_ae_e, ''),
  hes_did_e = NULLIF(@hes_did_e, ''),
  cr_e = NULLIF(@cr_e, ''),
  sact_e = NULLIF(@sact_e, ''),
  rtds_e = NULLIF(@rtds_e, ''),
  bsa_dispensing_e = NULLIF(@bsa_dispensing_e, '');
-- hes_patient:

CREATE TABLE IF NOT EXISTS ethnicity_record (
  patid bigint(20) NOT NULL,
  ethnic_6 tinyint(4) DEFAULT NULL
)
ENGINE=InnoDB
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_1/ethnicity_record_24_004516.txt'
IGNORE
INTO TABLE ethnicity_record
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(patid, ethnic_6);

-- patient_2019_imd:

DROP TABLE IF EXISTS patient_2019_imd

CREATE TABLE IF NOT EXISTS patient_2019_imd
(patid BIGINT UNSIGNED NOT NULL,
pracid MEDIUMINT,
e2019_imd_20 TINYINT
)
ENGINE=InnoDB
CHARSET=utf8mb4;


LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_1/patient_2019_imd_24_004516.txt'
INTO TABLE patient_2019_imd
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@patid, @pracid, @imd)
SET
  patid = NULLIF(@patid, ''),
  pracid = NULLIF(@pracid, ''),
  e2019_imd_20 = NULLIF(@imd, '');

--  practiceImd:

DROP TABLE IF EXISTS practice_imd

CREATE TABLE IF NOT EXISTS practice_imd
(pracid MEDIUMINT NOT NULL,
country VARCHAR(9),
e2015_imd_10 TINYINT,
ni2017_imd_10 TINYINT,
s2016_imd_10 TINYINT,
w2014_imd_10 TINYINT
)
CHARSET=utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_1/practice_imd_24_004516.txt' 
IGNORE
INTO TABLE practice_imd
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(pracid, country, @e2015_imd_10, @ni2017_imd_10, @s2016_imd_10, @w2014_imd_10)
SET e2015_imd_10 = NULLIF(@e2015_imd_10,''),
ni2017_imd_10 = NULLIF(@ni2017_imd_10,''),
s2016_imd_10 = NULLIF(@s2016_imd_10,''),
w2014_imd_10 = NULLIF(@w2014_imd_10,'');
--  death_patient:

DROP TABLE IF EXISTS patient_death;

CREATE TABLE patient_death (
    patid                    BIGINT  UNSIGNED NOT NULL,
    pracid                   INT,

    icd9_orig_mention_1      VARCHAR(6),
    icd9_orig_mention_2      VARCHAR(6),
    icd9_orig_mention_3      VARCHAR(6),
    icd9_orig_mention_4      VARCHAR(6),
    icd9_orig_mention_5      VARCHAR(6),
    icd9_orig_mention_6      VARCHAR(6),
    icd9_orig_mention_7      VARCHAR(6),
    icd9_orig_mention_8      VARCHAR(6),
    icd9_orig_mention_9      VARCHAR(6),
    icd9_orig_mention_10     VARCHAR(6),
    icd9_orig_mention_11     VARCHAR(6),
    icd9_orig_mention_12     VARCHAR(6),
    icd9_orig_mention_13     VARCHAR(6),
    icd9_orig_mention_14     VARCHAR(6),
    icd9_orig_mention_15     VARCHAR(6),

    neo_nate_flag            VARCHAR(6),

    pod_code                 VARCHAR(20),
    pod_establishment_type   VARCHAR(6),
    pod_nhs_establishment    TINYINT,

    reg_date                 DATE,
    reg_date_of_death        DATE,

    s_cod_code_1             VARCHAR(6),
    s_cod_code_2             VARCHAR(6),
    s_cod_code_3             VARCHAR(6),
    s_cod_code_4             VARCHAR(6),
    s_cod_code_5             VARCHAR(6),
    s_cod_code_6             VARCHAR(6),
    s_cod_code_7             VARCHAR(6),
    s_cod_code_8             VARCHAR(6),
    s_cod_code_9             VARCHAR(6),
    s_cod_code_10            VARCHAR(6),
    s_cod_code_11            VARCHAR(6),
    s_cod_code_12            VARCHAR(6),
    s_cod_code_13            VARCHAR(6),
    s_cod_code_14            VARCHAR(6),
    s_cod_code_15            VARCHAR(6),

    s_underlying_cod_icd10   VARCHAR(6),
    s_underlying_cod_icd9    VARCHAR(6)

)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_1/death_patient_24_004516.txt'
IGNORE
INTO TABLE patient_death
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    @patid,
    @pracid,

    @icd9_orig_mention_1,
    @icd9_orig_mention_2,
    @icd9_orig_mention_3,
    @icd9_orig_mention_4,
    @icd9_orig_mention_5,
    @icd9_orig_mention_6,
    @icd9_orig_mention_7,
    @icd9_orig_mention_8,
    @icd9_orig_mention_9,
    @icd9_orig_mention_10,
    @icd9_orig_mention_11,
    @icd9_orig_mention_12,
    @icd9_orig_mention_13,
    @icd9_orig_mention_14,
    @icd9_orig_mention_15,

    @neo_nate_flag,

    @pod_code,
    @pod_establishment_type,
    @pod_nhs_establishment,

    @reg_date,
    @reg_date_of_death,

    @s_cod_code_1,
    @s_cod_code_2,
    @s_cod_code_3,
    @s_cod_code_4,
    @s_cod_code_5,
    @s_cod_code_6,
    @s_cod_code_7,
    @s_cod_code_8,
    @s_cod_code_9,
    @s_cod_code_10,
    @s_cod_code_11,
    @s_cod_code_12,
    @s_cod_code_13,
    @s_cod_code_14,
    @s_cod_code_15,

    @s_underlying_cod_icd10,
    @s_underlying_cod_icd9
)
SET
    patid = NULLIF(TRIM(@patid), ''),
    pracid = NULLIF(TRIM(@pracid), ''),

    icd9_orig_mention_1 =
        NULLIF(TRIM(@icd9_orig_mention_1), ''),
    icd9_orig_mention_2 =
        NULLIF(TRIM(@icd9_orig_mention_2), ''),
    icd9_orig_mention_3 =
        NULLIF(TRIM(@icd9_orig_mention_3), ''),
    icd9_orig_mention_4 =
        NULLIF(TRIM(@icd9_orig_mention_4), ''),
    icd9_orig_mention_5 =
        NULLIF(TRIM(@icd9_orig_mention_5), ''),
    icd9_orig_mention_6 =
        NULLIF(TRIM(@icd9_orig_mention_6), ''),
    icd9_orig_mention_7 =
        NULLIF(TRIM(@icd9_orig_mention_7), ''),
    icd9_orig_mention_8 =
        NULLIF(TRIM(@icd9_orig_mention_8), ''),
    icd9_orig_mention_9 =
        NULLIF(TRIM(@icd9_orig_mention_9), ''),
    icd9_orig_mention_10 =
        NULLIF(TRIM(@icd9_orig_mention_10), ''),
    icd9_orig_mention_11 =
        NULLIF(TRIM(@icd9_orig_mention_11), ''),
    icd9_orig_mention_12 =
        NULLIF(TRIM(@icd9_orig_mention_12), ''),
    icd9_orig_mention_13 =
        NULLIF(TRIM(@icd9_orig_mention_13), ''),
    icd9_orig_mention_14 =
        NULLIF(TRIM(@icd9_orig_mention_14), ''),
    icd9_orig_mention_15 =
        NULLIF(TRIM(@icd9_orig_mention_15), ''),

    neo_nate_flag =
        NULLIF(TRIM(@neo_nate_flag), ''),

    pod_code =
        NULLIF(TRIM(@pod_code), ''),

    pod_establishment_type =
        NULLIF(TRIM(@pod_establishment_type), ''),

    pod_nhs_establishment =
        NULLIF(TRIM(@pod_nhs_establishment), ''),

    reg_date =
        STR_TO_DATE(
            NULLIF(TRIM(@reg_date), ''),
            '%Y-%m-%d'
        ),

    reg_date_of_death =
        STR_TO_DATE(
            NULLIF(TRIM(@reg_date_of_death), ''),
            '%Y-%m-%d'
        ),

    s_cod_code_1 =
        NULLIF(TRIM(@s_cod_code_1), ''),
    s_cod_code_2 =
        NULLIF(TRIM(@s_cod_code_2), ''),
    s_cod_code_3 =
        NULLIF(TRIM(@s_cod_code_3), ''),
    s_cod_code_4 =
        NULLIF(TRIM(@s_cod_code_4), ''),
    s_cod_code_5 =
        NULLIF(TRIM(@s_cod_code_5), ''),
    s_cod_code_6 =
        NULLIF(TRIM(@s_cod_code_6), ''),
    s_cod_code_7 =
        NULLIF(TRIM(@s_cod_code_7), ''),
    s_cod_code_8 =
        NULLIF(TRIM(@s_cod_code_8), ''),
    s_cod_code_9 =
        NULLIF(TRIM(@s_cod_code_9), ''),
    s_cod_code_10 =
        NULLIF(TRIM(@s_cod_code_10), ''),
    s_cod_code_11 =
        NULLIF(TRIM(@s_cod_code_11), ''),
    s_cod_code_12 =
        NULLIF(TRIM(@s_cod_code_12), ''),
    s_cod_code_13 =
        NULLIF(TRIM(@s_cod_code_13), ''),
    s_cod_code_14 =
        NULLIF(TRIM(@s_cod_code_14), ''),
    s_cod_code_15 =
        NULLIF(TRIM(@s_cod_code_15), ''),

    s_underlying_cod_icd10 =
        NULLIF(TRIM(@s_underlying_cod_icd10), ''),

    s_underlying_cod_icd9 =
        NULLIF(TRIM(@s_underlying_cod_icd9), '');