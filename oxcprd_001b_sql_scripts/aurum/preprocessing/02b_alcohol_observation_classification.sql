-- 03. Alcohol observation-level classification
--
-- Depends on objects created in 02_alcohol.sql:
--   aurum_oxcprd_001b.alcohol_units_observation_classified
--   alcohol_phenotype_observation
--   preproc_patient_candidates
--
-- Data flow:
--   * alcohol_units_observation_classified contains the unit-based
--     observations from codelist codes originally labelled 'check_upd'.
--     Only rows accepted by the unit-resolution logic are used here.
--   * alcohol_phenotype_observation contains directly classified CPRD
--     observations: aud, light-drinker, heavy-drinker and non-drinker.
--     alc_test was excluded upstream and needs no handling here.
--
-- AUD thresholds:
--   gender = 1: > 50 units/week
--   gender = 2: > 35 units/week
--
-- For ranged unit observations, a category is assigned only when the whole
-- range falls within that category. Ranges crossing alc_category_2
-- boundaries at 0, 7, 14 or the gender-specific AUD threshold are retained
-- with NULL alc_category_2 and status REVIEW. Specific crossed boundaries
-- are recorded in alc_category_2_reject_reason.
--
-- Extreme values:
--   reject when either weekly_units_low or weekly_units_high is > 300.
--
-- alc_category_2 splits the six light-drinker medcodeids:
--   Intrinsic trivial-drinker:
--     250321015, 397729013, 855071000006115, 4533271000006119
--
--   250312016: Light drinker - 1-2u/day
--     valid numunitid: 247, 1509, 288
--     value = 0        -> invalid: ZERO_NOT_ALLOWED
--     0 < value <= 1   -> trivial-drinker
--     1 < value <= 2   -> light-moderate
--     value > 2        -> invalid: outside medcodeid range
--
--   250322010: Ex-light drinker - (1-2u/day)
--     Investigation found no suitable numunitids for this code.
--     ALL occurrences are therefore invalid for alc_category_2.
USE aurum_oxcprd_001b;

/* -------------------------------------------------------------------------
1. Create observation-level alcohol categories
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS aurum_oxcprd_001b.alcohol_observation_category_classified;

CREATE TABLE aurum_oxcprd_001b.alcohol_observation_category_classified ENGINE = InnoDB AS
WITH
  unit_base AS (
    SELECT
      u.patid,
      u.eventdate,
      u.medcodeid,
      u.obstypeid,
      u.`value`,
      u.numunitid,
      u.term,
      u.weekly_units_low,
      u.weekly_units_high,
      p.gender,
      CASE p.gender
        WHEN 1 THEN 50
        WHEN 2 THEN 35
      END AS aud_threshold
    FROM
      aurum_oxcprd_001b.alcohol_units_observation_classified AS u
      INNER JOIN preproc_patient_candidates AS p ON p.patid = u.patid
    WHERE
      u.status = 'ACCEPT'
  ),
  unit_rules AS (
    SELECT
      u.*,
      CASE
        WHEN u.weekly_units_low IS NULL
        OR u.weekly_units_high IS NULL THEN 'WEEKLY_UNITS_MISSING'
        WHEN u.weekly_units_low > u.weekly_units_high THEN 'WEEKLY_LOW_GT_HIGH'
        WHEN u.weekly_units_low > 300
        OR u.weekly_units_high > 300 THEN 'EXTREME_WEEKLY_UNITS_GT_300'
        ELSE NULL
      END AS data_reject_reason,
      CASE
        WHEN u.weekly_units_low <= u.aud_threshold
        AND u.weekly_units_high > u.aud_threshold THEN 'RANGE_CROSSES_AUD_THRESHOLD'
        ELSE NULL
      END AS alc_category_review_reason,
      NULLIF(
        CONCAT_WS(
          ';',
          CASE
            WHEN u.weekly_units_low = 0
            AND u.weekly_units_high > 0 THEN 'RANGE_CROSSES_NONDRINKER_THRESHOLD'
          END,
          CASE
            WHEN u.weekly_units_low <= 7
            AND u.weekly_units_high > 7 THEN 'RANGE_CROSSES_7_UNIT_THRESHOLD'
          END,
          CASE
            WHEN u.weekly_units_low <= 14
            AND u.weekly_units_high > 14 THEN 'RANGE_CROSSES_14_UNIT_THRESHOLD'
          END,
          CASE
            WHEN u.weekly_units_low <= u.aud_threshold
            AND u.weekly_units_high > u.aud_threshold THEN 'RANGE_CROSSES_AUD_THRESHOLD'
          END
        ),
        ''
      ) AS alc_category_2_review_reason
    FROM
      unit_base AS u
  ),
  unit_classified AS (
    SELECT
      'alcohol_units_observation_classified' AS source_table,
      u.patid,
      u.eventdate,
      u.medcodeid,
      u.obstypeid,
      u.`value`,
      u.numunitid,
      u.term,
      CAST(NULL AS CHAR(255)) AS strict_phenotype,
      u.gender,
      u.weekly_units_low,
      u.weekly_units_high,
      /* alc_category: original weekly-unit classification. */
      CASE
        WHEN u.data_reject_reason IS NOT NULL
        OR u.alc_category_review_reason IS NOT NULL THEN NULL
        WHEN u.weekly_units_low = 0
        AND u.weekly_units_high = 0 THEN 'non-drinker'
        WHEN u.weekly_units_low > u.aud_threshold THEN 'aud'
        WHEN u.weekly_units_high <= 14 THEN 'light-drinker'
        ELSE 'heavy-drinker'
      END AS alc_category,
      CASE
        WHEN u.data_reject_reason IS NOT NULL THEN 'REJECT'
        WHEN u.alc_category_review_reason IS NOT NULL THEN 'REVIEW'
        ELSE 'ACCEPT'
      END AS alc_category_status,
      COALESCE(u.data_reject_reason, u.alc_category_review_reason) AS alc_category_reject_reason,
      /* alc_category_2: finer low-consumption categories. */
      CASE
        WHEN u.data_reject_reason IS NOT NULL
        OR u.alc_category_2_review_reason IS NOT NULL THEN NULL
        WHEN u.weekly_units_low = 0
        AND u.weekly_units_high = 0 THEN 'non-drinker'
        WHEN u.weekly_units_low > u.aud_threshold THEN 'aud'
        WHEN u.weekly_units_low > 0
        AND u.weekly_units_high <= 7 THEN 'trivial-drinker'
        WHEN u.weekly_units_low > 7
        AND u.weekly_units_high <= 14 THEN 'light-moderate'
        ELSE 'heavy-drinker'
      END AS alc_category_2,
      CASE
        WHEN u.data_reject_reason IS NOT NULL THEN 'REJECT'
        WHEN u.alc_category_2_review_reason IS NOT NULL THEN 'REVIEW'
        ELSE 'ACCEPT'
      END AS alc_category_2_status,
      COALESCE(u.data_reject_reason, u.alc_category_2_review_reason) AS alc_category_2_reject_reason
    FROM
      unit_rules AS u
  ),
  phenotype_classified AS (
    SELECT
      'alcohol_phenotype_observation' AS source_table,
      o.patid,
      o.eventdate,
      o.medcodeid,
      o.obstypeid,
      o.`value`,
      o.numunitid,
      o.term,
      o.strict_phenotype,
      p.gender,
      CAST(NULL AS DECIMAL(18, 6)) AS weekly_units_low,
      CAST(NULL AS DECIMAL(18, 6)) AS weekly_units_high,
      o.alc_category,
      'ACCEPT' AS alc_category_status,
      CAST(NULL AS CHAR(255)) AS alc_category_reject_reason,
      /* Only light-drinker codes need further classification. */
      CASE
        WHEN o.alc_category <> 'light-drinker' THEN o.alc_category
        WHEN o.medcodeid = 250322010 THEN NULL
        WHEN o.medcodeid IN (250321015, 397729013, 855071000006115, 4533271000006119) THEN 'trivial-drinker'
        WHEN o.medcodeid = 250312016
        AND o.numunitid IN (247, 1509, 288)
        AND o.`value` > 0
        AND o.`value` <= 1 THEN 'trivial-drinker'
        WHEN o.medcodeid = 250312016
        AND o.numunitid IN (247, 1509, 288)
        AND o.`value` > 1
        AND o.`value` <= 2 THEN 'light-moderate'
        ELSE NULL
      END AS alc_category_2,
      CASE
        WHEN o.alc_category <> 'light-drinker' THEN 'ACCEPT'
        WHEN o.medcodeid = 250322010 THEN 'REJECT'
        WHEN o.medcodeid IN (250321015, 397729013, 855071000006115, 4533271000006119) THEN 'ACCEPT'
        WHEN o.medcodeid = 250312016
        AND o.numunitid IN (247, 1509, 288)
        AND o.`value` > 0
        AND o.`value` <= 2 THEN 'ACCEPT'
        ELSE 'REJECT'
      END AS alc_category_2_status,
      CASE
        WHEN o.alc_category <> 'light-drinker' THEN NULL
        WHEN o.medcodeid = 250322010 THEN 'NO_SUITABLE_NUMUNITID_FOR_MEDCODE_250322010'
        WHEN o.medcodeid IN (250321015, 397729013, 855071000006115, 4533271000006119) THEN NULL
        WHEN o.medcodeid = 250312016
        AND o.numunitid IS NULL THEN 'LIGHT_SPLIT_NUMUNIT_NULL'
        WHEN o.medcodeid = 250312016
        AND o.numunitid NOT IN (247, 1509, 288) THEN 'LIGHT_SPLIT_NUMUNIT_NOT_VALID'
        WHEN o.medcodeid = 250312016
        AND o.`value` IS NULL THEN 'LIGHT_SPLIT_VALUE_NULL'
        WHEN o.medcodeid = 250312016
        AND o.`value` < 0 THEN 'LIGHT_SPLIT_NEGATIVE_VALUE'
        WHEN o.medcodeid = 250312016
        AND o.`value` = 0 THEN 'ZERO_NOT_ALLOWED'
        WHEN o.medcodeid = 250312016
        AND o.`value` > 2 THEN 'LIGHT_SPLIT_VALUE_OUTSIDE_MEDCODE_RANGE_GT_2_PER_DAY'
        WHEN o.medcodeid = 250312016
        AND o.`value` > 0
        AND o.`value` <= 2 THEN NULL
        ELSE 'UNEXPECTED_LIGHT_DRINKER_MEDCODE'
      END AS alc_category_2_reject_reason
    FROM
      alcohol_phenotype_observation AS o
      INNER JOIN preproc_patient_candidates AS p ON p.patid = o.patid
  )
SELECT
  source_table,
  patid,
  eventdate,
  medcodeid,
  obstypeid,
  `value`,
  numunitid,
  term,
  strict_phenotype,
  gender,
  weekly_units_low,
  weekly_units_high,
  alc_category,
  alc_category_status,
  alc_category_reject_reason,
  alc_category_2,
  alc_category_2_status,
  alc_category_2_reject_reason
FROM
  unit_classified
UNION ALL
SELECT
  source_table,
  patid,
  eventdate,
  medcodeid,
  obstypeid,
  `value`,
  numunitid,
  term,
  strict_phenotype,
  gender,
  weekly_units_low,
  weekly_units_high,
  alc_category,
  alc_category_status,
  alc_category_reject_reason,
  alc_category_2,
  alc_category_2_status,
  alc_category_2_reject_reason
FROM
  phenotype_classified;

ALTER TABLE aurum_oxcprd_001b.alcohol_observation_category_classified
ADD INDEX idx_alc_obs_patid_eventdate (patid, eventdate),
ADD INDEX idx_alc_obs_medcodeid (medcodeid),
ADD INDEX idx_alc_obs_category (alc_category),
ADD INDEX idx_alc_obs_category_2 (alc_category_2);

/* -------------------------------------------------------------------------
2. QC summaries
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS aurum_oxcprd_001b.v_qc_alcohol_observation_classification;

CREATE TABLE aurum_oxcprd_001b.v_qc_alcohol_observation_classification AS
SELECT
  source_table,
  alc_category,
  alc_category_status,
  alc_category_reject_reason,
  alc_category_2,
  alc_category_2_status,
  alc_category_2_reject_reason,
  COUNT(*) AS n_rows,
  COUNT(DISTINCT patid) AS n_patients
FROM
  aurum_oxcprd_001b.alcohol_observation_category_classified
GROUP BY
  source_table,
  alc_category,
  alc_category_status,
  alc_category_reject_reason,
  alc_category_2,
  alc_category_2_status,
  alc_category_2_reject_reason;

/* -------------------------------------------------------------------------
3. QC for the two value/numunitid-dependent light-drinker codes

250322010 is retained here to document the observed numunitids even though
all occurrences are invalid for alc_category_2.
------------------------------------------------------------------------- */
DROP TABLE IF EXISTS aurum_oxcprd_001b.v_qc_alcohol_light_split_codes;

CREATE TABLE aurum_oxcprd_001b.v_qc_alcohol_light_split_codes AS
SELECT
  medcodeid,
  numunitid,
  alc_category_2,
  alc_category_2_status,
  alc_category_2_reject_reason,
  COUNT(*) AS n_rows,
  COUNT(DISTINCT patid) AS n_patients,
  MIN(`value`) AS min_value,
  MAX(`value`) AS max_value
FROM
  aurum_oxcprd_001b.alcohol_observation_category_classified
WHERE
  medcodeid IN (250312016, 250322010)
GROUP BY
  medcodeid,
  numunitid,
  alc_category_2,
  alc_category_2_status,
  alc_category_2_reject_reason;

/*
select alc_category, count(distinct(patid)) as count_distinct_patid from alcohol_observation_category_classified group by alc_category;
+------------------+----------------------+
| alc_category     | count_distinct_patid |
+------------------+----------------------+
| NULL             |                  387 |
| aud              |               106130 |
| light-drinker    |               769439 |
| heavy-drinker    |               193077 |
| non-drinker      |               803784 |
+------------------+----------------------+

select alc_category_2, count(distinct(patid)) as count_distinct_patid from alcohol_observation_category_classified group by alc_category_2;
+------------------+----------------------+
| alc_category_2   | count_distinct_patid |
+------------------+----------------------+
| NULL             |                98238 |
| aud              |               106130 |
| light-moderate   |               246542 |
| heavy-drinker    |               193077 |
| non-drinker      |               803784 |
| trivial-drinker  |               656490 |
+------------------+----------------------+

select count(distinct patid) from alcohol_observation_category_classified where alc_category_2 in ('light-moderate', 'trivial-drinker');
+-----------------------+
| count(distinct patid) |
+-----------------------+
|                744364 |
+-----------------------+

lose approx (not considering group overlaps) 769,439 - 744,364 =25,075 in the process but we have 'cleaner groups'
*/
