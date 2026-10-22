-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
-- 04. GP consultation days and registration length in months.
--
-- Consultation count is unchanged: distinct dates in the inclusive
-- [MAX(regstartdate, index - 365 days), index] window.
-- Approximate month lengths use elapsed calendar days / 30.0, retaining
-- Decimal months: 30 elapsed days = 1 month; 45 = 1.5; same-day registration = 0.
USE aurum_oxcprd_001b;

DROP TABLE IF EXISTS preproc_patient_gp_dementia;

CREATE TABLE preproc_patient_gp_dementia ENGINE = InnoDB AS
WITH
  patient_windows AS (
    SELECT
      p.patid,
      p.dementia_index_date,
      pc.regstartdate,
      GREATEST(pc.regstartdate, DATE_SUB(p.dementia_index_date, INTERVAL 365 DAY)) AS gp_window_start_date
    FROM
      analysis_pop AS p
      LEFT JOIN preproc_patient_candidates AS pc ON pc.patid = p.patid
  ),
  consultation_counts AS (
    SELECT
      p.patid,
      COUNT(DISTINCT c.consdate) AS n_gp_consult_days_12m_pre_dementia
    FROM
      patient_windows AS p
      LEFT JOIN consultation AS c ON c.patid = p.patid
      AND c.consdate >= p.gp_window_start_date
      AND c.consdate <= p.dementia_index_date
    GROUP BY
      p.patid
  )
SELECT
  p.patid,
  p.dementia_index_date,
  p.regstartdate,
  p.gp_window_start_date,
  ROUND(GREATEST(DATEDIFF(p.dementia_index_date, p.regstartdate), 0) / 30.0, 4) AS gp_registration_months,
  ROUND(GREATEST(DATEDIFF(p.dementia_index_date, p.gp_window_start_date), 0) / 30.0, 4) AS gp_observed_months_pre_dementia,
  c.n_gp_consult_days_12m_pre_dementia
FROM
  patient_windows AS p
  INNER JOIN consultation_counts AS c ON c.patid = p.patid;

ALTER TABLE preproc_patient_gp_dementia
ADD PRIMARY KEY (patid),
ADD INDEX idx_patient_gp_dementia_date (dementia_index_date);

DROP TABLE IF EXISTS qc_patient_gp_dementia_counts;

CREATE TABLE qc_patient_gp_dementia_counts ENGINE = InnoDB AS
SELECT
  COUNT(*) AS n_analysis_patients,
  SUM(n_gp_consult_days_12m_pre_dementia > 0) AS n_with_consultation_day,
  SUM(n_gp_consult_days_12m_pre_dementia) AS n_consultation_days,
  MIN(n_gp_consult_days_12m_pre_dementia) AS min_consultation_days_per_patient,
  MAX(n_gp_consult_days_12m_pre_dementia) AS max_consultation_days_per_patient,
  MIN(gp_registration_months) AS min_registration_months,
  MAX(gp_registration_months) AS max_registration_months,
  MIN(gp_observed_months_pre_dementia) AS min_observed_months,
  MAX(gp_observed_months_pre_dementia) AS max_observed_months,
  SUM(
    regstartdate > DATE_SUB(dementia_index_date, INTERVAL 365 DAY)
    AND regstartdate <= dementia_index_date
  ) AS n_with_shorter_registration_history,
  SUM(regstartdate > dementia_index_date) AS n_with_registration_after_index,
  SUM(gp_observed_months_pre_dementia IS NULL) AS n_with_missing_window
FROM
  preproc_patient_gp_dementia;
