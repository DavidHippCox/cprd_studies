-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
-- this was used to create table 1 v2
-- Run after 07_analysis_dataset.sql.
-- Saves the final seven-column report as table1_summary.
-- B2 is a subset of B1; Total includes A + B1 only.
-- Percentages use all participants in the column, including missing values.
-- Clinical AUD remains pending extraction.
USE aurum_oxcprd_001b;
\W
DROP TEMPORARY TABLE IF EXISTS tmp_table1_groups,
tmp_table1_variables,
tmp_table1_membership,
tmp_table1_stats,
tmp_table1_category_counts,
tmp_table1_categories,
tmp_table1_report;

CREATE TEMPORARY TABLE tmp_table1_groups (group_code VARCHAR(8) PRIMARY KEY) ENGINE = InnoDB;

INSERT INTO
  tmp_table1_groups
VALUES
  ('A'),
  ('B1'),
  ('B2'),
  ('Total');

CREATE TEMPORARY TABLE tmp_table1_variables (
  row_order SMALLINT NOT NULL,
  variable VARCHAR(64) PRIMARY KEY,
  label VARCHAR(128) NOT NULL,
  summary_kind VARCHAR(16) NOT NULL
) ENGINE = InnoDB;

INSERT INTO
  tmp_table1_variables
VALUES
  (10, 'number', 'Number of participants', 'number'),
  (20, 'sex', 'Sex', 'categorical'),
  (30, 'ethnicity', 'Ethnicity', 'categorical'),
  (40, 'imd_2019', 'Patient IMD 2019 group', 'categorical'),
  (50, 'age', 'Age at dementia index (years)', 'continuous'),
  (60, 'bmi', 'BMI', 'continuous'),
  (70, 'gp_registration', 'GP registration duration (months)', 'continuous'),
  (80, 'gp_consultation', 'Consultation dates in pre-index year', 'continuous'),
  (90, 'dementia_subtype', 'Dementia subtype', 'categorical'),
  (100, 'type2_diabetes', 'Type 2 diabetes', 'binary'),
  (110, 'hypertension', 'Hypertension', 'binary'),
  (120, 'ihd', 'Ischaemic heart disease', 'binary'),
  (130, 'wernicke_encephalopathy', 'Wernicke''s encephalopathy', 'binary'),
  (140, 'smoking', 'Smoking', 'categorical'),
  (150, 'thiamine', 'Thiamine prescription', 'binary'),
  (160, 'clinical_aud', 'Purely clinically coded AUD', 'pending'),
  (170, 'arld', 'Alcohol-related liver disease', 'binary'),
  (180, 'depression_anxiety', 'Baseline depression or anxiety', 'binary'),
  (190, 'smi', 'Baseline severe mental illness', 'binary'),
  (200, 'tbi', 'Baseline traumatic brain injury', 'binary'),
  (210, 'alcohol_category', 'Alcohol exposure category', 'categorical');

-- Reuse membership keys without copying patient records.
CREATE TEMPORARY TABLE tmp_table1_membership ENGINE = InnoDB AS
SELECT
  p.patid,
  g.group_code
FROM
  analysis_table1 AS p
  INNER JOIN tmp_table1_groups AS g ON (
    g.group_code = p.group_ab
    AND p.group_ab IN ('A', 'B1')
  )
  OR (
    g.group_code = 'B2'
    AND p.group_ab = 'B1'
    AND p.b2_flag = 1
  )
  OR (
    g.group_code = 'Total'
    AND p.group_ab IN ('A', 'B1')
  );

ALTER TABLE tmp_table1_membership
ADD PRIMARY KEY (group_code, patid),
ADD INDEX (patid);

-- Aggregate scalar values in one pass, including empty groups.
CREATE TEMPORARY TABLE tmp_table1_stats ENGINE = InnoDB AS
SELECT
  g.group_code,
  COUNT(p.patid) AS group_n,
  AVG (p.age_at_dementia_index) AS age_mean,
  STDDEV_SAMP(p.age_at_dementia_index) AS age_sd,
  COUNT(p.patid) - COUNT(p.age_at_dementia_index) AS age_missing,
  AVG (p.bmi_value) AS bmi_mean,
  STDDEV_SAMP(p.bmi_value) AS bmi_sd,
  COUNT(p.patid) - COUNT(p.bmi_value) AS bmi_missing,
  AVG (p.gp_registration_months) AS gp_registration_mean,
  STDDEV_SAMP(p.gp_registration_months) AS gp_registration_sd,
  COUNT(p.patid) - COUNT(p.gp_registration_months) AS gp_registration_missing,
  AVG (p.n_gp_consult_days_12m_pre_dementia) AS gp_consultation_mean,
  STDDEV_SAMP(p.n_gp_consult_days_12m_pre_dementia) AS gp_consultation_sd,
  COUNT(p.patid) - COUNT(p.n_gp_consult_days_12m_pre_dementia) AS gp_consultation_missing,
  COALESCE(SUM(p.type2_diabetes = 1), 0) AS type2_diabetes_n,
  COALESCE(SUM(p.hypertension = 1), 0) AS hypertension_n,
  COALESCE(SUM(p.ihd = 1), 0) AS ihd_n,
  COALESCE(SUM(p.wernicke_encephalopathy = 1), 0) AS wernicke_encephalopathy_n,
  COALESCE(SUM(p.thiamine = 1), 0) AS thiamine_n,
  COALESCE(SUM(p.arld = 1), 0) AS arld_n,
  COALESCE(SUM(p.dep_anx = 1), 0) AS depression_anxiety_n,
  COALESCE(SUM(p.smi = 1), 0) AS smi_n,
  COALESCE(SUM(p.tbi = 1), 0) AS tbi_n
FROM
  tmp_table1_groups AS g
  LEFT JOIN tmp_table1_membership AS m ON m.group_code = g.group_code
  LEFT JOIN analysis_table1 AS p ON p.patid = m.patid
GROUP BY
  g.group_code;

CREATE TEMPORARY TABLE tmp_table1_category_counts ENGINE = InnoDB AS
WITH
  category_values AS (
    SELECT
      m.group_code,
      v.variable,
      COALESCE(
        TRIM(
          CASE v.variable
            WHEN 'sex' THEN CAST(p.sex_label AS CHAR)
            WHEN 'ethnicity' THEN CAST(p.ethnicity_label AS CHAR)
            WHEN 'imd_2019' THEN CAST(p.imd_2019_quintile AS CHAR)
            WHEN 'dementia_subtype' THEN CAST(p.dementia_subtype AS CHAR)
            WHEN 'smoking' THEN CAST(p.smoking_status AS CHAR)
            WHEN 'alcohol_category' THEN CAST(p.alc_group AS CHAR)
          END
        ),
        ''
      ) AS category_code
    FROM
      tmp_table1_membership AS m
      INNER JOIN analysis_table1 AS p ON p.patid = m.patid
      CROSS JOIN tmp_table1_variables AS v
    WHERE
      v.summary_kind = 'categorical'
  )
SELECT
  group_code,
  variable,
  category_code,
  COUNT(*) AS category_n
FROM
  category_values
GROUP BY
  group_code,
  variable,
  category_code;

-- Keep known categories even when absent; include other observed labels.
-- Empty category_code represents NULL or blank source values.
CREATE TEMPORARY TABLE tmp_table1_categories (
  variable VARCHAR(64) NOT NULL,
  category_code VARCHAR(255) NOT NULL,
  category_order SMALLINT NOT NULL,
  PRIMARY KEY (variable, category_code)
) ENGINE = InnoDB;

INSERT INTO
  tmp_table1_categories
VALUES
  ('sex', 'Male', 1),
  ('sex', 'Female', 2),
  ('sex', 'Unknown', 3),
  ('ethnicity', 'Asian', 1),
  ('ethnicity', 'Black', 2),
  ('ethnicity', 'Mixed/multiple', 3),
  ('ethnicity', 'White', 4),
  ('ethnicity', 'Other', 5),
  ('ethnicity', 'Unknown', 6),
  ('smoking', 'non-smoker', 1),
  ('smoking', 'current-smoker', 2),
  ('smoking', 'ex-smoker', 3),
  ('imd_2019', '1', 1),
  ('imd_2019', '2', 2),
  ('imd_2019', '3', 3),
  ('imd_2019', '4', 4),
  ('imd_2019', '5', 5),
  ('alcohol_category', 'non-drinker', 1),
  ('alcohol_category', 'trivial-drinker', 2),
  ('alcohol_category', 'aud', 3);

INSERT INTO
  tmp_table1_categories
SELECT
  variable,
  '',
  999
FROM
  tmp_table1_variables
WHERE
  summary_kind = 'categorical';

INSERT INTO
  tmp_table1_categories
SELECT
  variable,
  category_code,
  100
FROM
  tmp_table1_category_counts
WHERE
  category_code <> ''
GROUP BY
  variable,
  category_code
ON DUPLICATE KEY UPDATE
  category_order = LEAST(category_order, 100);

CREATE TEMPORARY TABLE tmp_table1_report ENGINE = InnoDB AS
WITH
  scalar_values AS (
    SELECT
      v.row_order,
      v.variable,
      v.label,
      v.summary_kind,
      CASE
        WHEN v.summary_kind IN ('binary', 'pending') THEN 'Yes'
        ELSE ''
      END AS category_label,
      s.group_code,
      s.group_n,
      CASE v.variable
        WHEN 'number' THEN s.group_n
        WHEN 'type2_diabetes' THEN s.type2_diabetes_n
        WHEN 'hypertension' THEN s.hypertension_n
        WHEN 'ihd' THEN s.ihd_n
        WHEN 'wernicke_encephalopathy' THEN s.wernicke_encephalopathy_n
        WHEN 'thiamine' THEN s.thiamine_n
        WHEN 'arld' THEN s.arld_n
        WHEN 'depression_anxiety' THEN s.depression_anxiety_n
        WHEN 'smi' THEN s.smi_n
        WHEN 'tbi' THEN s.tbi_n
      END AS n,
      CASE v.variable
        WHEN 'age' THEN s.age_mean
        WHEN 'bmi' THEN s.bmi_mean
        WHEN 'gp_registration' THEN s.gp_registration_mean
        WHEN 'gp_consultation' THEN s.gp_consultation_mean
      END AS mean_value,
      CASE v.variable
        WHEN 'age' THEN s.age_sd
        WHEN 'bmi' THEN s.bmi_sd
        WHEN 'gp_registration' THEN s.gp_registration_sd
        WHEN 'gp_consultation' THEN s.gp_consultation_sd
      END AS sd_value,
      CASE v.variable
        WHEN 'age' THEN s.age_missing
        WHEN 'bmi' THEN s.bmi_missing
        WHEN 'gp_registration' THEN s.gp_registration_missing
        WHEN 'gp_consultation' THEN s.gp_consultation_missing
      END AS n_missing
    FROM
      tmp_table1_stats AS s
      CROSS JOIN tmp_table1_variables AS v
    WHERE
      v.summary_kind <> 'categorical'
  ),
  summary_rows AS (
    SELECT
      row_order,
      variable,
      label,
      summary_kind,
      category_label AS category_code,
      category_label,
      1 AS category_order,
      group_code,
      group_n,
      n,
      mean_value,
      sd_value
    FROM
      scalar_values
    UNION ALL
    SELECT
      row_order,
      variable,
      label,
      'missing',
      '',
      'Missing',
      999,
      group_code,
      group_n,
      n_missing,
      NULL,
      NULL
    FROM
      scalar_values
    WHERE
      summary_kind = 'continuous'
    UNION ALL
    SELECT
      v.row_order,
      v.variable,
      v.label,
      v.summary_kind,
      c.category_code,
      CASE
        WHEN c.category_code = '' THEN 'Missing'
        ELSE c.category_code
      END,
      c.category_order,
      s.group_code,
      s.group_n,
      COALESCE(f.category_n, 0),
      NULL,
      NULL
    FROM
      tmp_table1_categories AS c
      INNER JOIN tmp_table1_variables AS v ON v.variable = c.variable
      CROSS JOIN tmp_table1_stats AS s
      LEFT JOIN tmp_table1_category_counts AS f ON f.group_code = s.group_code
      AND f.variable = c.variable
      AND f.category_code = c.category_code
  ),
  report_values AS (
    SELECT
      s.row_order,
      s.variable,
      s.label,
      s.category_code,
      s.category_label,
      s.category_order,
      s.group_code,
      r.statistic,
      r.statistic_order,
      CASE
        WHEN s.summary_kind = 'pending' THEN 'Pending extraction'
        ELSE COALESCE(
          CASE r.statistic
            WHEN 'Count' THEN CAST(s.n AS CHAR)
            WHEN 'Column %' THEN CONCAT(FORMAT(CAST(100.0 * s.n / NULLIF(s.group_n, 0) AS DOUBLE), 2), '%')
            WHEN 'Mean' THEN FORMAT(CAST(s.mean_value AS DOUBLE), 2)
            WHEN 'SD' THEN FORMAT(s.sd_value, 2)
          END,
          '-'
        )
      END AS display_value
    FROM
      summary_rows AS s
      CROSS JOIN (
        SELECT
          'Count' AS statistic,
          1 AS statistic_order
        UNION ALL
        SELECT
          'Column %',
          2
        UNION ALL
        SELECT
          'Mean',
          3
        UNION ALL
        SELECT
          'SD',
          4
      ) AS r
    WHERE
      (
        s.summary_kind = 'continuous'
        AND r.statistic IN ('Mean', 'SD')
      )
      OR (
        s.summary_kind IN ('categorical', 'binary', 'pending', 'missing')
        AND r.statistic IN ('Count', 'Column %')
      )
      OR (
        s.summary_kind = 'number'
        AND r.statistic = 'Count'
      )
  )
SELECT
  row_order,
  category_order,
  category_code,
  statistic_order,
  label AS `Variable`,
  category_label AS `Value`,
  statistic AS `Statistic`,
  MAX(
    CASE
      WHEN group_code = 'A' THEN display_value
    END
  ) AS `Group A`,
  MAX(
    CASE
      WHEN group_code = 'B1' THEN display_value
    END
  ) AS `Group B1`,
  MAX(
    CASE
      WHEN group_code = 'B2' THEN display_value
    END
  ) AS `Group B2`,
  MAX(
    CASE
      WHEN group_code = 'Total' THEN display_value
    END
  ) AS `Total (A + B1)`
FROM
  report_values
GROUP BY
  row_order,
  variable,
  label,
  category_code,
  category_label,
  category_order,
  statistic_order,
  statistic;

DROP TABLE IF EXISTS table1_summary;

CREATE TABLE table1_summary ENGINE = InnoDB AS
SELECT
  `Variable`,
  `Value`,
  `Statistic`,
  `Group A`,
  `Group B1`,
  `Group B2`,
  `Total (A + B1)`
FROM
  tmp_table1_report
ORDER BY
  row_order,
  category_order,
  `Value`,
  statistic_order;

-- Return the report with an explicit display order.
SELECT
  `Variable`,
  `Value`,
  `Statistic`,
  `Group A`,
  `Group B1`,
  `Group B2`,
  `Total (A + B1)`
FROM
  tmp_table1_report
ORDER BY
  row_order,
  category_order,
  `Value`,
  statistic_order;

DROP TEMPORARY TABLE tmp_table1_groups,
tmp_table1_variables,
tmp_table1_membership,
tmp_table1_stats,
tmp_table1_category_counts,
tmp_table1_categories,
tmp_table1_report;
