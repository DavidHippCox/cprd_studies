USE aurum_oxcprd_001b;

SET
  SESSION group_concat_max_len = 1000000;

SET
  @sql = (
    SELECT
      CONCAT(
        'SELECT ',
        GROUP_CONCAT(
          QUOTE(column_name)
          ORDER BY
            ordinal_position
        ),
        ' UNION ALL SELECT ',
        GROUP_CONCAT(
          CONCAT('`', column_name, '`')
          ORDER BY
            ordinal_position
        ),
        ' FROM `',
        table_name,
        '`',
        ' INTO OUTFILE ',
        QUOTE('{{STUDY_001B_ROOT}}/aurum/rawdata/death_patient.txt'),
        ' FIELDS TERMINATED BY ''\\t''',
        ' LINES TERMINATED BY ''\\r\\n'''
      )
    FROM
      information_schema.columns
    WHERE
      table_schema = DATABASE ()
      AND table_name = 'death_patient'
  );

PREPARE stmt
FROM
  @sql;

EXECUTE stmt;

DEALLOCATE PREPARE stmt;

CREATE TABLE death_patient_deduplicated LIKE death_patient;

ALTER TABLE death_patient_deduplicated
ADD COLUMN match_type VARCHAR(50);

-- RUN AFTER ONS_DEATH_DEDUP R SCRIPT.
LOAD DATA INFILE '{{STUDY_001B_ROOT}}/aurum/rawdata/death_patient_deduplicated.txt' IGNORE INTO TABLE death_patient_deduplicated FIELDS TERMINATED BY '\t' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES (
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
  @s_underlying_cod_icd9,
  @match_type
)
SET
  patid = NULLIF(NULLIF(TRIM(@patid), ''), '\\N'),
  pracid = NULLIF(NULLIF(TRIM(@pracid), ''), '\\N'),
  icd9_orig_mention_1 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_1), ''), '\\N'),
  icd9_orig_mention_2 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_2), ''), '\\N'),
  icd9_orig_mention_3 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_3), ''), '\\N'),
  icd9_orig_mention_4 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_4), ''), '\\N'),
  icd9_orig_mention_5 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_5), ''), '\\N'),
  icd9_orig_mention_6 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_6), ''), '\\N'),
  icd9_orig_mention_7 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_7), ''), '\\N'),
  icd9_orig_mention_8 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_8), ''), '\\N'),
  icd9_orig_mention_9 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_9), ''), '\\N'),
  icd9_orig_mention_10 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_10), ''), '\\N'),
  icd9_orig_mention_11 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_11), ''), '\\N'),
  icd9_orig_mention_12 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_12), ''), '\\N'),
  icd9_orig_mention_13 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_13), ''), '\\N'),
  icd9_orig_mention_14 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_14), ''), '\\N'),
  icd9_orig_mention_15 = NULLIF(NULLIF(TRIM(@icd9_orig_mention_15), ''), '\\N'),
  neo_nate_flag = NULLIF(NULLIF(TRIM(@neo_nate_flag), ''), '\\N'),
  pod_code = NULLIF(NULLIF(TRIM(@pod_code), ''), '\\N'),
  pod_establishment_type = NULLIF(NULLIF(TRIM(@pod_establishment_type), ''), '\\N'),
  pod_nhs_establishment = NULLIF(NULLIF(TRIM(@pod_nhs_establishment), ''), '\\N'),
  reg_date = STR_TO_DATE(NULLIF(NULLIF(TRIM(@reg_date), ''), '\\N'), '%Y-%m-%d'),
  reg_date_of_death = STR_TO_DATE(NULLIF(NULLIF(TRIM(@reg_date_of_death), ''), '\\N'), '%Y-%m-%d'),
  s_cod_code_1 = NULLIF(NULLIF(TRIM(@s_cod_code_1), ''), '\\N'),
  s_cod_code_2 = NULLIF(NULLIF(TRIM(@s_cod_code_2), ''), '\\N'),
  s_cod_code_3 = NULLIF(NULLIF(TRIM(@s_cod_code_3), ''), '\\N'),
  s_cod_code_4 = NULLIF(NULLIF(TRIM(@s_cod_code_4), ''), '\\N'),
  s_cod_code_5 = NULLIF(NULLIF(TRIM(@s_cod_code_5), ''), '\\N'),
  s_cod_code_6 = NULLIF(NULLIF(TRIM(@s_cod_code_6), ''), '\\N'),
  s_cod_code_7 = NULLIF(NULLIF(TRIM(@s_cod_code_7), ''), '\\N'),
  s_cod_code_8 = NULLIF(NULLIF(TRIM(@s_cod_code_8), ''), '\\N'),
  s_cod_code_9 = NULLIF(NULLIF(TRIM(@s_cod_code_9), ''), '\\N'),
  s_cod_code_10 = NULLIF(NULLIF(TRIM(@s_cod_code_10), ''), '\\N'),
  s_cod_code_11 = NULLIF(NULLIF(TRIM(@s_cod_code_11), ''), '\\N'),
  s_cod_code_12 = NULLIF(NULLIF(TRIM(@s_cod_code_12), ''), '\\N'),
  s_cod_code_13 = NULLIF(NULLIF(TRIM(@s_cod_code_13), ''), '\\N'),
  s_cod_code_14 = NULLIF(NULLIF(TRIM(@s_cod_code_14), ''), '\\N'),
  s_cod_code_15 = NULLIF(NULLIF(TRIM(@s_cod_code_15), ''), '\\N'),
  s_underlying_cod_icd10 = NULLIF(NULLIF(TRIM(@s_underlying_cod_icd10), ''), '\\N'),
  s_underlying_cod_icd9 = NULLIF(NULLIF(TRIM(@s_underlying_cod_icd9), ''), '\\N'),
  match_type = NULLIF(NULLIF(TRIM(@match_type), ''), '\\N');