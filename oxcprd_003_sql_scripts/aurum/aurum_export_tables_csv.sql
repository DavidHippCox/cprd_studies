USE aurum_oxcprd_003;

DELIMITER $$
DROP PROCEDURE IF EXISTS export_table$$
CREATE PROCEDURE export_table (IN p_root VARCHAR(1000), IN p_table VARCHAR(255))
BEGIN DECLARE v_header LONGTEXT;

DECLARE v_columns LONGTEXT;

SELECT
  GROUP_CONCAT(
    CONCAT(
      '''',
      REPLACE
        (column_name, '''', ''''''),
        ''''
    )
    ORDER BY
      ordinal_position SEPARATOR ', '
  ),
  GROUP_CONCAT(
    CONCAT(
      '`',
      REPLACE
        (column_name, '`', '``'),
        '`'
    )
    ORDER BY
      ordinal_position SEPARATOR ', '
  ) INTO v_header,
  v_columns
FROM
  information_schema.columns
WHERE
  table_schema = 'aurum_oxcprd_003'
  AND table_name = p_table;

IF v_columns IS NULL THEN
SIGNAL SQLSTATE '45000'
SET
  MESSAGE_TEXT = 'Export table does not exist';

END IF;

SET
  @sql = CONCAT(
    'SELECT ',
    v_header,
    ' UNION ALL SELECT ',
    v_columns,
    ' FROM ',
    'aurum_oxcprd_003.`',
    REPLACE
      (p_table, '`', '``'),
      '` ',
      'INTO OUTFILE ''',
    REPLACE
      (p_root, '''', ''''''),
      '/',
    REPLACE
      (p_table, '''', ''''''),
      '.csv'' ',
      'FIELDS TERMINATED BY '','' ',
      'LINES TERMINATED BY ''\r\n'''
  );

PREPARE stmt
FROM
  @sql;

EXECUTE stmt;

DEALLOCATE PREPARE stmt;

END $$ DELIMITER;

CALL export_table (
  '{{STUDY_003_ROOT}}/exported_from_mariadb',
  'aud_thiamine_only_patids_abs_30d'
);

CALL export_table (
  '{{STUDY_003_ROOT}}/exported_from_mariadb',
  'aud_thiamine_only_patids_30d'
);

CALL export_table (
  '{{STUDY_003_ROOT}}/exported_from_mariadb',
  'candidate_patids'
);

CALL export_table (
  '{{STUDY_003_ROOT}}/exported_from_mariadb',
  'thiamine_only_drug_drugissue'
);

CALL export_table (
  '{{STUDY_003_ROOT}}/exported_from_mariadb',
  'linkage_eligibility'
);

CALL export_table ('{{STUDY_003_ROOT}}/exported_from_mariadb', 'patient');

CALL export_table (
  '{{STUDY_003_ROOT}}/exported_from_mariadb',
  'patient_2019_imd'
);

CALL export_table (
  '{{STUDY_003_ROOT}}/exported_from_mariadb',
  'ethnicity_record'
);

DESCRIBE aud_thiamine_only_patids_abs_30d;
