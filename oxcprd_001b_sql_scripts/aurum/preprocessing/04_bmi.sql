-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- this was used to create table 1 v1
-- BMI before dementia index for CPRD Aurum.
--
USE aurum_oxcprd_001b;

/* ----------------------------------------------------------------------
1. Unify the accepted BMI, height, and weight code/unit mappings
------------------------------------------------------------------------ */
DROP TEMPORARY TABLE IF EXISTS tmp_bmi_measurement_map;

CREATE TEMPORARY TABLE tmp_bmi_measurement_map (
  measurement_type VARCHAR(6) NOT NULL,
  medcodeid BIGINT UNSIGNED NOT NULL,
  numunitid BIGINT UNSIGNED NULL,
  conversion_rule VARCHAR(20) NOT NULL,
  INDEX idx_bmi_map_code_unit (medcodeid, numunitid)
) ENGINE = InnoDB;

INSERT INTO
  tmp_bmi_measurement_map (measurement_type, medcodeid, numunitid, conversion_rule)
SELECT
  'bmi',
  c.medcodeid,
  u.numunitid,
  u.conversion_rule
FROM
  v0_bmi_codes_AURUM AS c
  INNER JOIN v0_bmi_numunitid_aurum AS u ON u.medcodeid = c.medcodeid
UNION ALL
SELECT
  'bmi',
  c.medcodeid,
  NULL,
  'identity'
FROM
  v0_bmi_codes_AURUM AS c
UNION ALL
SELECT
  'height',
  c.medcodeid,
  u.numunitid,
  u.conversion_rule
FROM
  v0_height_codes_AURUM AS c
  INNER JOIN v0_height_numunitid_aurum AS u ON u.medcodeid = c.medcodeid
UNION ALL
SELECT
  'weight',
  c.medcodeid,
  u.numunitid,
  u.conversion_rule
FROM
  v0_weight_codes_AURUM AS c
  INNER JOIN v0_weight_numunitid_aurum AS u ON u.medcodeid = c.medcodeid;

/* ----------------------------------------------------------------------
2. One cohort-restricted scan of observation
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_bmi_measurements;

CREATE TABLE tmp_bmi_measurements ENGINE = InnoDB AS
SELECT
  x.patid,
  x.dementia_index_date,
  x.eventdate,
  x.measurement_type,
  x.measurement_value
FROM
  (
    SELECT
      p.patid,
      p.dementia_index_date,
      o.obsdate AS eventdate,
      m.measurement_type,
      CAST(
        CASE m.conversion_rule
          WHEN 'cm_to_m' THEN o.value / 100
          WHEN 'ft_to_m' THEN o.value * 0.3048
          WHEN 'inch_to_m' THEN o.value * 0.0254
          WHEN 'stone_to_kg' THEN o.value * 6.35029318
          WHEN 'pounds_to_kg' THEN o.value * 0.45359237
          ELSE o.value
        END AS DECIMAL(18, 6)
      ) AS measurement_value
    FROM
      analysis_pop AS p
      INNER JOIN observation AS o ON o.patid = p.patid
      AND o.obsdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR)
      AND o.obsdate <= p.dementia_index_date
      INNER JOIN tmp_bmi_measurement_map AS m ON m.medcodeid = o.medcodeid
      AND m.numunitid <=> o.numunitid
    WHERE
      o.value IS NOT NULL
      AND o.obstypeid <> 4
  ) AS x
WHERE
  (
    x.measurement_type = 'bmi'
    AND x.measurement_value BETWEEN 10 AND 80
  )
  OR (
    x.measurement_type = 'height'
    AND x.measurement_value BETWEEN 1.3 AND 2.2
  )
  OR (
    x.measurement_type = 'weight'
    AND x.measurement_value BETWEEN 30 AND 300
  );

ALTER TABLE tmp_bmi_measurements
ADD INDEX idx_tmp_bmi_measurement_type_patient_date (measurement_type, patid, eventdate),
ADD INDEX idx_tmp_bmi_measurement_patient_date (patid, eventdate);

/* ----------------------------------------------------------------------
3. Most recent BMI, height, and weight measurements
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS tmp_bmi_latest_measurements;

CREATE TABLE tmp_bmi_latest_measurements ENGINE = InnoDB AS
SELECT
  ranked.patid,
  MAX(
    CASE
      WHEN ranked.measurement_type = 'bmi' THEN ranked.eventdate
    END
  ) AS recent_bmi_date,
  MAX(
    CASE
      WHEN ranked.measurement_type = 'bmi' THEN ranked.measurement_value
    END
  ) AS recent_bmi,
  MAX(
    CASE
      WHEN ranked.measurement_type = 'height' THEN ranked.eventdate
    END
  ) AS recent_height_date,
  MAX(
    CASE
      WHEN ranked.measurement_type = 'height' THEN ranked.measurement_value
    END
  ) AS recent_height_m,
  MAX(
    CASE
      WHEN ranked.measurement_type = 'weight' THEN ranked.eventdate
    END
  ) AS recent_weight_date,
  MAX(
    CASE
      WHEN ranked.measurement_type = 'weight' THEN ranked.measurement_value
    END
  ) AS recent_weight_kg
FROM
  (
    SELECT
      m.patid,
      m.eventdate,
      m.measurement_type,
      m.measurement_value,
      ROW_NUMBER() OVER (
        PARTITION BY
          m.patid,
          m.measurement_type
        ORDER BY
          m.eventdate DESC,
          m.measurement_value DESC
      ) AS measurement_recency_rank
    FROM
      tmp_bmi_measurements AS m
  ) AS ranked
WHERE
  ranked.measurement_recency_rank = 1
GROUP BY
  ranked.patid;

ALTER TABLE tmp_bmi_latest_measurements
ADD PRIMARY KEY (patid);

/* ----------------------------------------------------------------------
4. One BMI record per dementia patient
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS preproc_patient_bmi_dementia;

CREATE TABLE preproc_patient_bmi_dementia ENGINE = InnoDB AS
SELECT
  p.patid,
  p.dementia_index_date,
  CASE
    WHEN c.recent_bmi IS NOT NULL
    AND (
      c.derived_bmi IS NULL
      OR c.recent_bmi_date >= c.recent_weight_date
    ) THEN c.recent_bmi_date
    WHEN c.derived_bmi IS NOT NULL THEN c.recent_weight_date
    ELSE NULL
  END AS bmi_event_date,
  ROUND(
    CASE
      WHEN c.recent_bmi IS NOT NULL
      AND (
        c.derived_bmi IS NULL
        OR c.recent_bmi_date >= c.recent_weight_date
      ) THEN c.recent_bmi
      WHEN c.derived_bmi IS NOT NULL THEN c.derived_bmi
      ELSE NULL
    END,
    2
  ) AS bmi_value,
  CASE
    WHEN c.recent_bmi IS NOT NULL
    AND (
      c.derived_bmi IS NULL
      OR c.recent_bmi_date >= c.recent_weight_date
    ) THEN 'recorded_bmi'
    WHEN c.derived_bmi IS NOT NULL THEN 'derived_weight_recent_height'
    ELSE NULL
  END AS bmi_value_source,
  ROUND(c.recent_height_m, 4) AS bmi_height_m_recent,
  ROUND(c.recent_weight_kg, 3) AS bmi_weight_kg_recent,
  ROUND(c.recent_bmi, 3) AS bmi_recorded_recent
FROM
  analysis_pop AS p
  LEFT JOIN (
    SELECT
      m.patid,
      m.recent_bmi_date,
      m.recent_bmi,
      m.recent_height_m,
      m.recent_weight_date,
      m.recent_weight_kg,
      CASE
        WHEN m.recent_weight_kg IS NOT NULL
        AND m.recent_height_m IS NOT NULL
        AND m.recent_height_m > 0
        AND m.recent_weight_kg / POW(m.recent_height_m, 2) BETWEEN 10 AND 80  THEN m.recent_weight_kg / POW(m.recent_height_m, 2)
        ELSE NULL
      END AS derived_bmi
    FROM
      tmp_bmi_latest_measurements AS m
  ) AS c ON c.patid = p.patid;

ALTER TABLE preproc_patient_bmi_dementia
ADD PRIMARY KEY (patid),
ADD INDEX idx_patient_bmi_dementia_date (dementia_index_date),
ADD INDEX idx_patient_bmi_event_date (bmi_event_date);

/* ----------------------------------------------------------------------
5. QC
------------------------------------------------------------------------ */
DROP TABLE IF EXISTS qc_patient_bmi_dementia_counts;

CREATE TABLE qc_patient_bmi_dementia_counts ENGINE = InnoDB AS
SELECT
  COUNT(*) AS n_dementia_patients,
  SUM(bmi_value IS NOT NULL) AS n_with_bmi,
  SUM(bmi_value_source = 'recorded_bmi') AS n_recorded_bmi,
  SUM(bmi_value_source LIKE 'derived_weight_recent_height%') AS n_derived_bmi,
  MIN(bmi_value) AS min_bmi,
  MAX(bmi_value) AS max_bmi
FROM
  preproc_patient_bmi_dementia;
