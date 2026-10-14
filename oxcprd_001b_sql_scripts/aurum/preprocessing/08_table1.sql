-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- this was used to create table 1 v1
-- Clinical AUD remains pending extraction.
USE aurum_oxcprd_001b;

/* sql-formatter-disable */
DELIMITER $$
/* sql-formatter-enable */
CREATE OR REPLACE PROCEDURE build_table1()
MODIFIES SQL DATA
BEGIN
  DECLARE v_done BOOLEAN DEFAULT FALSE;
  DECLARE v_variable VARCHAR(64);
  DECLARE v_kind VARCHAR(16);
  DECLARE v_column VARCHAR(64);
  DECLARE v_expression TEXT;
  DECLARE v_aggregates LONGTEXT DEFAULT '';
  DECLARE v_scalar_rows LONGTEXT DEFAULT '';
  DECLARE v_categories LONGTEXT DEFAULT '';
  DECLARE v_count TEXT;
  DECLARE v_nonmissing TEXT;
  DECLARE v_mean TEXT;
  DECLARE v_sd TEXT;
  DECLARE v_sql LONGTEXT;
  DECLARE variable_cursor CURSOR FOR
    SELECT variable, summary_kind, source_column
    FROM tmp_table1_variables ORDER BY row_order;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

  DROP TEMPORARY TABLE IF EXISTS tmp_table1_categories,
    tmp_table1_category_totals, tmp_table1_category_counts,
    tmp_table1_scalar_stats, tmp_table1_membership,
    tmp_table1_variables, tmp_table1_groups;

  CREATE TEMPORARY TABLE tmp_table1_groups (
    group_code VARCHAR(8) PRIMARY KEY,
    group_label VARCHAR(32) NOT NULL,
    group_order TINYINT NOT NULL
  ) ENGINE = InnoDB;
  INSERT INTO tmp_table1_groups VALUES
    ('A', 'Group A', 1), ('B1', 'Group B1', 2),
    ('B2', 'Group B2', 3), ('Total', 'Total A + B1', 4);

  -- Fixed column whitelist. Each variable's source is defined only here.
  CREATE TEMPORARY TABLE tmp_table1_variables (
    row_order SMALLINT NOT NULL,
    variable VARCHAR(64) PRIMARY KEY,
    label VARCHAR(128) NOT NULL,
    summary_kind VARCHAR(16) NOT NULL,
    source_column VARCHAR(64) NULL
  ) ENGINE = InnoDB;
  INSERT INTO tmp_table1_variables VALUES
    (10, 'number', 'Number of participants', 'number', NULL),
    (20, 'sex', 'Sex', 'categorical', 'sex_label'),
    (30, 'ethnicity', 'Ethnicity', 'categorical', 'ethnicity_label'),
    (40, 'imd_2019', 'Patient IMD 2019 group', 'categorical',
      'imd_2019_quintile'),
    (50, 'age', 'Age at dementia index (years)', 'continuous',
      'age_at_dementia_index'),
    (60, 'bmi', 'BMI', 'continuous', 'bmi_value'),
    (70, 'gp_registration', 'GP registration duration (months)',
      'continuous', 'gp_registration_months'),
    (80, 'gp_consultation', 'Consultation dates in pre-index year',
      'continuous', 'n_gp_consult_days_12m_pre_dementia'),
    (90, 'dementia_subtype', 'Dementia subtype', 'categorical',
      'dementia_subtype'),
    (100, 'type2_diabetes', 'Type 2 diabetes', 'binary',
      'type2_diabetes'),
    (110, 'hypertension', 'Hypertension', 'binary', 'hypertension'),
    (120, 'ihd', 'Ischaemic heart disease', 'binary', 'ihd'),
    (130, 'wernicke_encephalopathy', 'Wernicke''s encephalopathy',
      'binary', 'wernicke_encephalopathy'),
    (140, 'smoking', 'Smoking', 'categorical', 'smoking_status'),
    (150, 'thiamine', 'Thiamine prescription', 'binary', 'thiamine'),
    (160, 'clinical_aud', 'Purely clinically coded AUD', 'pending', NULL),
    (170, 'arld', 'Alcohol-related liver disease', 'binary', 'arld'),
    (180, 'depression_anxiety', 'Baseline depression or anxiety',
      'binary', 'dep_anx'),
    (190, 'smi', 'Baseline severe mental illness', 'binary', 'smi'),
    (200, 'tbi', 'Baseline traumatic brain injury', 'binary', 'tbi'),
    (210, 'alcohol_category', 'Alcohol exposure category',
      'categorical', 'alc_group');

  -- Store only patient/group keys, not duplicated patient records.
  CREATE TEMPORARY TABLE tmp_table1_membership ENGINE = InnoDB AS
  SELECT p.patid, g.group_code
  FROM analysis_table1 AS p
  INNER JOIN tmp_table1_groups AS g ON
    (g.group_code = p.group_ab AND p.group_ab IN ('A', 'B1'))
    OR (g.group_code = 'B2' AND p.group_ab = 'B1' AND p.b2_flag = 1)
    OR (g.group_code = 'Total' AND p.group_ab IN ('A', 'B1'));
  ALTER TABLE tmp_table1_membership
    ADD PRIMARY KEY (group_code, patid), ADD INDEX (patid);

  -- Generate wide aggregates once; unpivot only the four summary rows.
  OPEN variable_cursor;
  variable_loop: LOOP
    FETCH variable_cursor INTO v_variable, v_kind, v_column;
    IF v_done THEN LEAVE variable_loop; END IF;
    SET v_expression = CONCAT('p.`', v_column, '`');
    IF v_kind = 'categorical' THEN
      SET v_categories = CONCAT(v_categories,
        ' WHEN ', QUOTE(v_variable), ' THEN CAST(', v_expression,
        ' AS CHAR)');
      ITERATE variable_loop;
    END IF;

    SET v_count = 'NULL', v_nonmissing = 'NULL',
      v_mean = 'NULL', v_sd = 'NULL';
    IF v_kind = 'number' THEN
      SET v_count = 's.group_n', v_nonmissing = 's.group_n';
    ELSEIF v_kind IN ('continuous', 'binary') THEN
      SET v_aggregates = CONCAT(v_aggregates,
        ', COUNT(', v_expression, ') AS `', v_variable, '_n`');
      SET v_nonmissing = CONCAT('s.`', v_variable, '_n`');
      IF v_kind = 'continuous' THEN
        SET v_aggregates = CONCAT(v_aggregates,
          ', AVG(', v_expression, ') AS `', v_variable, '_mean`',
          ', STDDEV_SAMP(', v_expression, ') AS `', v_variable, '_sd`');
        SET v_mean = CONCAT('s.`', v_variable, '_mean`'),
          v_sd = CONCAT('s.`', v_variable, '_sd`');
      ELSE
        SET v_aggregates = CONCAT(v_aggregates,
          ', COALESCE(SUM(', v_expression, ' = 1), 0) AS `',
          v_variable, '_count`');
        SET v_count = CONCAT('s.`', v_variable, '_count`');
      END IF;
    END IF;
    SET v_scalar_rows = CONCAT_WS(' UNION ALL ',
      NULLIF(v_scalar_rows, ''), CONCAT(
      'SELECT ''0.3'', v.row_order, v.variable, v.label, v.summary_kind,
        CASE WHEN v.summary_kind IN (''binary'', ''pending'')
          THEN ''1'' ELSE '''' END,
        CASE WHEN v.summary_kind IN (''binary'', ''pending'')
          THEN ''Yes'' ELSE '''' END,
        0, 1, g.group_code, g.group_label, g.group_order, s.group_n, ',
      v_count, ', 100.0 * ', v_count, ' / NULLIF(s.group_n, 0), ',
      v_mean, ', ', v_sd, ', ', v_nonmissing, ', s.group_n - ',
      v_nonmissing, ',
        CASE WHEN v.summary_kind = ''pending''
          THEN ''pending_extraction'' ELSE ''available'' END
      FROM tmp_table1_scalar_stats AS s
      INNER JOIN tmp_table1_groups AS g ON g.group_code = s.group_code
      INNER JOIN tmp_table1_variables AS v ON v.variable = ',
      QUOTE(v_variable)));
  END LOOP;
  CLOSE variable_cursor;

  SET v_sql = CONCAT(
    'CREATE TEMPORARY TABLE tmp_table1_scalar_stats ENGINE = InnoDB AS
     SELECT g.group_code, COUNT(p.patid) AS group_n', v_aggregates, '
     FROM tmp_table1_groups AS g
     LEFT JOIN tmp_table1_membership AS m ON m.group_code = g.group_code
     LEFT JOIN analysis_table1 AS p ON p.patid = m.patid
     GROUP BY g.group_code');
  EXECUTE IMMEDIATE v_sql;

  SET v_sql = CONCAT(
    'CREATE TEMPORARY TABLE tmp_table1_category_counts ENGINE = InnoDB AS
     WITH values_long AS (
       SELECT m.group_code, v.variable,
         NULLIF(TRIM(CASE v.variable ', v_categories, ' END), '''')
           AS category
       FROM tmp_table1_membership AS m
       INNER JOIN analysis_table1 AS p ON p.patid = m.patid
       CROSS JOIN tmp_table1_variables AS v
       WHERE v.summary_kind = ''categorical''
     )
     SELECT group_code, variable, COALESCE(category, '''') AS category_code,
       category IS NULL AS is_missing, COUNT(*) AS category_n
     FROM values_long GROUP BY group_code, variable, category');
  EXECUTE IMMEDIATE v_sql;

  CREATE TEMPORARY TABLE tmp_table1_category_totals ENGINE = InnoDB AS
  SELECT group_code, variable,
    SUM(CASE WHEN is_missing = 0 THEN category_n ELSE 0 END)
      AS n_nonmissing,
    SUM(CASE WHEN is_missing = 1 THEN category_n ELSE 0 END) AS n_missing
  FROM tmp_table1_category_counts GROUP BY group_code, variable;

  -- Seed known labels; observed unseeded labels remain visible.
  CREATE TEMPORARY TABLE tmp_table1_categories (
    variable VARCHAR(64) NOT NULL,
    category_code VARCHAR(255) NOT NULL,
    is_missing TINYINT NOT NULL,
    category_order SMALLINT NOT NULL,
    PRIMARY KEY (variable, category_code, is_missing)
  ) ENGINE = InnoDB;
  INSERT INTO tmp_table1_categories VALUES
    ('sex', 'Male', 0, 1), ('sex', 'Female', 0, 2),
    ('sex', 'Unknown', 0, 3),
    ('ethnicity', 'Asian', 0, 1), ('ethnicity', 'Black', 0, 2),
    ('ethnicity', 'Mixed/multiple', 0, 3), ('ethnicity', 'White', 0, 4),
    ('ethnicity', 'Other', 0, 5), ('ethnicity', 'Unknown', 0, 6),
    ('smoking', 'non-smoker', 0, 1),
    ('smoking', 'current-smoker', 0, 2), ('smoking', 'ex-smoker', 0, 3),
    ('imd_2019', '1', 0, 1), ('imd_2019', '2', 0, 2),
    ('imd_2019', '3', 0, 3), ('imd_2019', '4', 0, 4),
    ('imd_2019', '5', 0, 5),
    ('alcohol_category', 'non-drinker', 0, 1),
    ('alcohol_category', 'trivial-drinker', 0, 2),
    ('alcohol_category', 'aud', 0, 3);
  INSERT INTO tmp_table1_categories
  SELECT variable, '', 1, 999 FROM tmp_table1_variables
  WHERE summary_kind = 'categorical';
  INSERT INTO tmp_table1_categories
  SELECT variable, category_code, is_missing, 100
  FROM tmp_table1_category_counts
  WHERE is_missing = 0 GROUP BY variable, category_code, is_missing
  ON DUPLICATE KEY UPDATE category_order = LEAST(category_order, 100);

  DROP TABLE IF EXISTS table1_summary;
  CREATE TABLE table1_summary (
    plan_version VARCHAR(8) NOT NULL,
    row_order SMALLINT NOT NULL,
    variable VARCHAR(64) NOT NULL,
    label VARCHAR(128) NOT NULL,
    summary_kind VARCHAR(16) NOT NULL,
    category_code VARCHAR(255) NOT NULL,
    category_label VARCHAR(255) NOT NULL,
    is_missing TINYINT NOT NULL,
    category_order SMALLINT NOT NULL,
    group_code VARCHAR(8) NOT NULL,
    group_label VARCHAR(32) NOT NULL,
    group_order TINYINT NOT NULL,
    group_n BIGINT UNSIGNED NOT NULL,
    `count` BIGINT UNSIGNED NULL,
    percentage DOUBLE NULL,
    `mean` DOUBLE NULL,
    sd DOUBLE NULL,
    n_nonmissing BIGINT UNSIGNED NULL,
    n_missing BIGINT UNSIGNED NULL,
    availability VARCHAR(32) NOT NULL,
    PRIMARY KEY (variable, category_code, is_missing, group_code)
  ) ENGINE = InnoDB;

  SET v_sql = CONCAT('INSERT INTO table1_summary ', v_scalar_rows);
  EXECUTE IMMEDIATE v_sql;
  INSERT INTO table1_summary
  SELECT '0.3', v.row_order, v.variable, v.label, v.summary_kind,
    c.category_code,
    CASE WHEN c.is_missing = 1 THEN 'Missing' ELSE c.category_code END,
    c.is_missing, c.category_order,
    g.group_code, g.group_label, g.group_order, s.group_n,
    COALESCE(f.category_n, 0),
    100.0 * COALESCE(f.category_n, 0) / NULLIF(s.group_n, 0),
    NULL, NULL, COALESCE(t.n_nonmissing, 0), COALESCE(t.n_missing, 0),
    'available'
  FROM tmp_table1_categories AS c
  INNER JOIN tmp_table1_variables AS v ON v.variable = c.variable
  CROSS JOIN tmp_table1_groups AS g
  INNER JOIN tmp_table1_scalar_stats AS s ON s.group_code = g.group_code
  LEFT JOIN tmp_table1_category_totals AS t
    ON t.group_code = g.group_code AND t.variable = c.variable
  LEFT JOIN tmp_table1_category_counts AS f
    ON f.group_code = g.group_code AND f.variable = c.variable
    AND f.category_code = c.category_code AND f.is_missing = c.is_missing;

  INSERT INTO table1_summary
  SELECT plan_version, row_order, variable, label, 'missing', '',
    'Missing', 1, 999, group_code, group_label, group_order, group_n,
    n_missing, 100.0 * n_missing / NULLIF(group_n, 0),
    NULL, NULL, n_nonmissing, n_missing, availability
  FROM table1_summary WHERE summary_kind = 'continuous';

  DROP TEMPORARY TABLE tmp_table1_categories,
    tmp_table1_category_totals, tmp_table1_category_counts,
    tmp_table1_scalar_stats, tmp_table1_membership,
    tmp_table1_variables, tmp_table1_groups;
END$$
/* sql-formatter-disable */
DELIMITER ;
/* sql-formatter-enable */

CALL build_table1();

-- Categorical/binary/Missing: Count and Column %. Continuous: Mean and SD.
WITH report_rows AS (
  SELECT s.row_order, s.variable, s.label, s.category_code,
    s.category_label, s.is_missing, s.category_order, s.group_code,
    r.statistic, r.statistic_order,
    CASE WHEN s.availability = 'pending_extraction'
      THEN 'Pending extraction'
      ELSE COALESCE(CASE r.statistic
        WHEN 'Count' THEN CAST(s.`count` AS CHAR)
        WHEN 'Column %' THEN CONCAT(FORMAT(s.percentage, 2), '%')
        WHEN 'Mean' THEN FORMAT(s.`mean`, 2)
        WHEN 'SD' THEN FORMAT(s.sd, 2)
      END, '-') END AS display_value
  FROM table1_summary AS s
  CROSS JOIN (
    SELECT 'Count' AS statistic, 1 AS statistic_order
    UNION ALL SELECT 'Column %', 2
    UNION ALL SELECT 'Mean', 3
    UNION ALL SELECT 'SD', 4
  ) AS r
  WHERE (s.summary_kind = 'continuous' AND r.statistic IN ('Mean', 'SD'))
    OR (s.summary_kind IN ('categorical', 'binary', 'pending', 'missing')
      AND r.statistic IN ('Count', 'Column %'))
    OR (s.summary_kind = 'number' AND r.statistic = 'Count')
)
SELECT label AS `Variable`, category_label AS `Value`,
  statistic AS `Statistic`,
  MAX(CASE WHEN group_code = 'A' THEN display_value END) AS `Group A`,
  MAX(CASE WHEN group_code = 'B1' THEN display_value END) AS `Group B1`,
  MAX(CASE WHEN group_code = 'B2' THEN display_value END) AS `Group B2`,
  MAX(CASE WHEN group_code = 'Total' THEN display_value END)
    AS `Total (A + B1)`
FROM report_rows
GROUP BY row_order, variable, label, category_code, category_label,
  is_missing, category_order, statistic_order, statistic
ORDER BY row_order, category_order, category_label, statistic_order;
