-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
-- analysis plan v2: prior history restricts sensitivity analyses only.
-- this was used to create table 1 v2
--
-- B2 overlaps B1; Total is A+B1.
-- Clinically coded AUD remains NULL/pending until separately extracted.
-- patid_imd quintiles are 1-4, 5-8, 9-12, 13-16, 17-20
-- 
-- future work: complete-case flag 
--
USE aurum_oxcprd_001b;

DROP TEMPORARY TABLE IF EXISTS tmp_analysis_outcome_config;

CREATE TEMPORARY TABLE tmp_analysis_outcome_config (
  feature VARCHAR(32) NOT NULL,
  outcome_prefix VARCHAR(64) NOT NULL,
  PRIMARY KEY (outcome_prefix)
) ENGINE = InnoDB;

INSERT INTO
  tmp_analysis_outcome_config
VALUES
  ('care_home', 'care_home'),
  ('medication', 'antipsychotics'),
  ('medication', 'antidepressants'),
  ('medication', 'antipsychotics_antidepressants'),
  ('medication', 'anxiety_and_hypnotics'),
  ('neuropsychiatric', 'psychosis'),
  ('neuropsychiatric', 'delirium'),
  ('neuropsychiatric', 'affective'),
  ('neuropsychiatric', 'challenging');

DROP TABLE IF EXISTS analysis_outcomes_long;

-- Keep every cohort patient/outcome; only in-follow-up dates reach models.
-- The source table retains out-of-follow-up dates for inspection.
CREATE TABLE analysis_outcomes_long ENGINE = InnoDB AS
WITH
  outcome_dates AS (
    SELECT
      p.patid,
      p.dementia_index_date,
      p.earliest_4,
      x.feature,
      x.outcome_prefix,
      o.patid IS NOT NULL AS outcome_source_present,
      o.first_pre_dem_eventdate,
      CASE
        WHEN o.first_post_dem_eventdate > p.dementia_index_date
        AND o.first_post_dem_eventdate <= p.earliest_4 THEN o.first_post_dem_eventdate
      END AS first_post_dem_eventdate,
      CASE
        WHEN o.first_post_dem_eventdate IS NULL THEN 0
        WHEN o.first_post_dem_eventdate > p.dementia_index_date
        AND o.first_post_dem_eventdate <= p.earliest_4 THEN 0
        ELSE 1
      END AS post_dem_date_excluded
    FROM
      analysis_pop AS p
      CROSS JOIN tmp_analysis_outcome_config AS x
      LEFT JOIN preproc_outcome_features_long AS o ON o.patid = p.patid
      AND o.outcome_prefix = x.outcome_prefix
      AND o.dementia_index_date = p.dementia_index_date
  )
SELECT
  r.patid,
  r.dementia_index_date,
  r.earliest_4,
  r.feature,
  r.outcome_prefix,
  r.first_pre_dem_eventdate,
  r.first_post_dem_eventdate,
  -- Derived fields remain here for QC, including missing source rows.
  CASE
    WHEN r.outcome_source_present THEN r.first_pre_dem_eventdate IS NULL
  END AS sensitivity_eligible,
  CASE
    WHEN r.outcome_source_present THEN r.first_post_dem_eventdate IS NOT NULL
  END AS event,
  CASE
    WHEN r.outcome_source_present THEN DATEDIFF(COALESCE(r.first_post_dem_eventdate, r.earliest_4), r.dementia_index_date)
  END AS time_days,
  r.post_dem_date_excluded
FROM
  outcome_dates AS r;

ALTER TABLE analysis_outcomes_long
ADD PRIMARY KEY (patid, outcome_prefix),
ADD INDEX idx_analysis_outcome_prefix (outcome_prefix);

DROP TABLE IF EXISTS analysis_dataset;

CREATE TABLE analysis_dataset ENGINE = InnoDB AS
SELECT
  p.patid,
  p.pracid,
  p.gender,
  p.yob_date,
  p.cprd_death,
  p.ons_death,
  p.merged_death,
  p.ethnic_6,
  p.e2015_imd_10,
  p.patid_imd,
  p.linkyear,
  p.earliest_4,
  p.latest_2,
  p.first_diag_mci_dementia,
  p.age_at_first_diag_mci_dementia,
  p.dementia_index_date,
  p.dementia_subtype,
  p.alc_group,
  p.group_ab,
  p.b2_flag,
  TIMESTAMPDIFF (YEAR, p.yob_date, p.dementia_index_date) AS age_at_dementia_index,
  DATEDIFF(p.earliest_4, p.dementia_index_date) AS followup_days_available,
  CASE
    WHEN p.patid_imd BETWEEN 1 AND 20  THEN CEIL(p.patid_imd / 4)
  END AS imd_2019_quintile,
  b.bmi_event_date,
  b.bmi_value,
  b.bmi_value_source,
  s.smoking_event_date,
  s.smoking_status,
  g.regstartdate,
  g.gp_registration_months,
  g.n_gp_consult_days_12m_pre_dementia,
  c.confounder_dep_anx_eventdate,
  c.confounder_smi_eventdate,
  c.confounder_tbi_eventdate,
  d.type2_diabetes_eventdate,
  d.hypertension_eventdate,
  d.ihd_eventdate,
  d.thiamine_eventdate,
  d.wernicke_encephalopathy_eventdate,
  d.arld_eventdate,
  d.donepezil_flag,
  d.rivastigmine_flag,
  d.galantamine_flag,
  d.memantine_flag,
  CAST(NULL AS UNSIGNED) AS clinical_aud,
  oc.first_pre_dem_eventdate AS care_home_pre_dem_eventdate,
  oc.first_post_dem_eventdate AS care_home_post_dem_eventdate,
  op.first_pre_dem_eventdate AS antipsychotics_pre_dem_eventdate,
  op.first_post_dem_eventdate AS antipsychotics_post_dem_eventdate,
  od.first_pre_dem_eventdate AS antidepressants_pre_dem_eventdate,
  od.first_post_dem_eventdate AS antidepressants_post_dem_eventdate,
  opd.first_pre_dem_eventdate AS antipsychotics_antidepressants_pre_dem_eventdate,
  opd.first_post_dem_eventdate AS antipsychotics_antidepressants_post_dem_eventdate,
  oh.first_pre_dem_eventdate AS anxiety_and_hypnotics_pre_dem_eventdate,
  oh.first_post_dem_eventdate AS anxiety_and_hypnotics_post_dem_eventdate,
  ops.first_pre_dem_eventdate AS psychosis_pre_dem_eventdate,
  ops.first_post_dem_eventdate AS psychosis_post_dem_eventdate,
  odl.first_pre_dem_eventdate AS delirium_pre_dem_eventdate,
  odl.first_post_dem_eventdate AS delirium_post_dem_eventdate,
  oaf.first_pre_dem_eventdate AS affective_pre_dem_eventdate,
  oaf.first_post_dem_eventdate AS affective_post_dem_eventdate,
  och.first_pre_dem_eventdate AS challenging_pre_dem_eventdate,
  och.first_post_dem_eventdate AS challenging_post_dem_eventdate
FROM
  analysis_pop AS p
  LEFT JOIN preproc_patient_bmi_dementia AS b ON b.patid = p.patid
  LEFT JOIN preproc_patient_smoking_dementia AS s ON s.patid = p.patid
  LEFT JOIN preproc_patient_gp_dementia AS g ON g.patid = p.patid
  LEFT JOIN preproc_patient_confounders_dementia AS c ON c.patid = p.patid
  LEFT JOIN preproc_patient_descriptives_dementia AS d ON d.patid = p.patid
  LEFT JOIN analysis_outcomes_long AS oc ON oc.patid = p.patid
  AND oc.outcome_prefix = 'care_home'
  LEFT JOIN analysis_outcomes_long AS op ON op.patid = p.patid
  AND op.outcome_prefix = 'antipsychotics'
  LEFT JOIN analysis_outcomes_long AS od ON od.patid = p.patid
  AND od.outcome_prefix = 'antidepressants'
  LEFT JOIN analysis_outcomes_long AS opd ON opd.patid = p.patid
  AND opd.outcome_prefix = 'antipsychotics_antidepressants'
  LEFT JOIN analysis_outcomes_long AS oh ON oh.patid = p.patid
  AND oh.outcome_prefix = 'anxiety_and_hypnotics'
  LEFT JOIN analysis_outcomes_long AS ops ON ops.patid = p.patid
  AND ops.outcome_prefix = 'psychosis'
  LEFT JOIN analysis_outcomes_long AS odl ON odl.patid = p.patid
  AND odl.outcome_prefix = 'delirium'
  LEFT JOIN analysis_outcomes_long AS oaf ON oaf.patid = p.patid
  AND oaf.outcome_prefix = 'affective'
  LEFT JOIN analysis_outcomes_long AS och ON och.patid = p.patid
  AND och.outcome_prefix = 'challenging';

ALTER TABLE analysis_dataset
ADD PRIMARY KEY (patid),
ADD INDEX idx_analysis_dataset_practice (pracid);

-- 3. Model export includes baseline disease dates and outcome dates.
-- Nonmissing post-dem dates are events strictly after index and through earliest_4.
-- R derives events and time; pre-dem dates identify sensitivity exclusions.
CREATE OR REPLACE VIEW analysis_model AS
SELECT
  a.patid,
  a.pracid,
  a.group_ab,
  a.b2_flag,
  a.alc_group,
  a.dementia_index_date,
  a.earliest_4,
  a.latest_2,
  a.merged_death,
  a.followup_days_available,
  a.age_at_dementia_index,
  a.gender,
  a.ethnic_6,
  a.imd_2019_quintile,
  a.bmi_value,
  a.smoking_status,
  a.n_gp_consult_days_12m_pre_dementia,
  a.gp_registration_months,
  a.confounder_dep_anx_eventdate,
  a.confounder_smi_eventdate,
  a.confounder_tbi_eventdate,
  a.type2_diabetes_eventdate,
  a.ihd_eventdate,
  a.care_home_pre_dem_eventdate,
  a.care_home_post_dem_eventdate,
  a.antipsychotics_pre_dem_eventdate,
  a.antipsychotics_post_dem_eventdate,
  a.antidepressants_pre_dem_eventdate,
  a.antidepressants_post_dem_eventdate,
  a.antipsychotics_antidepressants_pre_dem_eventdate,
  a.antipsychotics_antidepressants_post_dem_eventdate,
  a.anxiety_and_hypnotics_pre_dem_eventdate,
  a.anxiety_and_hypnotics_post_dem_eventdate,
  a.psychosis_pre_dem_eventdate,
  a.psychosis_post_dem_eventdate,
  a.delirium_pre_dem_eventdate,
  a.delirium_post_dem_eventdate,
  a.affective_pre_dem_eventdate,
  a.affective_post_dem_eventdate,
  a.challenging_pre_dem_eventdate,
  a.challenging_post_dem_eventdate
FROM
  analysis_dataset AS a;

-- 4. Table 1 / cross-tabulation view uses the same master patients.
CREATE OR REPLACE VIEW analysis_table1 AS
SELECT
  a.*,
  CASE a.gender
    WHEN 1 THEN 'Male'
    WHEN 2 THEN 'Female'
  END AS sex_label,
  CASE a.ethnic_6
    WHEN 1 THEN 'Asian'
    WHEN 2 THEN 'Black'
    WHEN 3 THEN 'Mixed/multiple'
    WHEN 4 THEN 'White'
    WHEN 5 THEN 'Other'
    WHEN 6 THEN 'Unknown'
  END AS ethnicity_label,
  a.type2_diabetes_eventdate IS NOT NULL AS type2_diabetes,
  a.hypertension_eventdate IS NOT NULL AS hypertension,
  a.ihd_eventdate IS NOT NULL AS ihd,
  a.wernicke_encephalopathy_eventdate IS NOT NULL AS wernicke_encephalopathy,
  a.thiamine_eventdate IS NOT NULL AS thiamine,
  a.arld_eventdate IS NOT NULL AS arld,
  a.confounder_dep_anx_eventdate IS NOT NULL AS dep_anx,
  a.confounder_smi_eventdate IS NOT NULL AS smi,
  a.confounder_tbi_eventdate IS NOT NULL AS tbi
FROM
  analysis_dataset AS a;

-- 5. QC is aggregated once from the generic long outcomes.
DROP TABLE IF EXISTS qc_analysis_dataset_outcomes;

CREATE TABLE qc_analysis_dataset_outcomes ENGINE = InnoDB AS
SELECT
  feature,
  outcome_prefix,
  COUNT(*) AS n_patients,
  COALESCE(SUM(sensitivity_eligible = 1), 0) AS n_sensitivity_eligible,
  COALESCE(SUM(sensitivity_eligible = 0), 0) AS n_sensitivity_excluded_prior,
  COALESCE(SUM(sensitivity_eligible IS NULL), 0) AS n_missing_outcome_source,
  COALESCE(SUM(event = 1), 0) AS n_events,
  COALESCE(
    SUM(
      sensitivity_eligible = 1
      AND event = 1
    ),
    0
  ) AS n_sensitivity_events,
  COALESCE(SUM(event = 0), 0) AS n_censored,
  COALESCE(SUM(post_dem_date_excluded), 0) AS n_excluded_post_dem_dates,
  COALESCE(
    SUM(
      first_post_dem_eventdate <= dementia_index_date
      OR first_post_dem_eventdate > earliest_4
    ),
    0
  ) AS n_post_dem_outside_followup,
  MIN(time_days) AS min_time_days,
  MAX(time_days) AS max_time_days
FROM
  analysis_outcomes_long
GROUP BY
  feature,
  outcome_prefix;

DROP TABLE IF EXISTS qc_analysis_dataset_counts;

CREATE TABLE qc_analysis_dataset_counts ENGINE = InnoDB AS
SELECT
  (
    SELECT
      COUNT(*)
    FROM
      analysis_pop
  ) AS n_analysis_pop,
  COUNT(*) AS n_analysis_dataset,
  (
    SELECT
      COUNT(*)
    FROM
      analysis_outcomes_long
  ) AS n_outcome_rows,
  SUM(bmi_value IS NULL) AS n_missing_bmi,
  SUM(smoking_status IS NULL) AS n_missing_smoking,
  SUM(gp_registration_months IS NULL) AS n_missing_gp_months,
  SUM(
    b2_flag = 1
    AND group_ab <> 'B1'
  ) AS n_b2_outside_b1
FROM
  analysis_dataset;

DROP TEMPORARY TABLE tmp_analysis_outcome_config;

-- Primary analysis: SELECT * FROM analysis_model;
-- Sensitivity: WHERE care_home_pre_dem_eventdate IS NULL.
-- Care-home event: care_home_post_dem_eventdate IS NOT NULL.
-- Other outcomes: time to the retained event, or censoring at earliest_4.
-- Cross-tabulations can use analysis_table1, which includes outcome fields.
