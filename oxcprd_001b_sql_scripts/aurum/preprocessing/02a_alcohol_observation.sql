-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- this was used to create table 1 v1
--
-- Assumptions:
--   * Medcodeid present in alcohol_unit_aurum iff alc_category = 'check_upd'!
USE aurum_oxcprd_001b;

/* -------------------------------------------------------------------------
1. Filtered Aurum Observation events
------------------------------------------------------------------------- */
-- check the unique values of alc_category in v0_alcohol_codes_AURUM
-- select distinct alc_category from v0_alcohol_codes_AURUM;
-- {aud, check_upd, light-drinker, heavy-drinker, non-drinker, alc_test} (no NUlls)
DELETE FROM alcohol_observation
-- CPRD Aurum ObsType 4 is Family history. 
WHERE
  obstypeid = 4;

-- retrieve alcohol unit observations for codes that have alc_category "check_upd" i.e medcodeids in alcohol_unit_aurum
CREATE TABLE aurum_oxcprd_001b.alcohol_units_observation_classified AS
WITH
  resolved AS (
    SELECT
      o.patid,
      o.eventdate,
      o.medcodeid,
      o.`value`,
      o.numunitid,
      o.obstypeid,
      m.term,
      m.term_has_unit,
      m.term_period,
      m.zero_allowed,
      n.numunitid AS matched_numunitid,
      n.description AS numunit_description,
      n.amount_type,
      n.amount_low,
      n.amount_high,
      n.numunit_has_unit,
      n.numunit_period,
      COALESCE(m.term_period, n.numunit_period) AS resolved_period,
      CASE
        WHEN n.numunit_period IS NOT NULL THEN n.weekly_multiplier
        WHEN m.term_period = 'DAY' THEN 7
        WHEN m.term_period = 'WEEK' THEN 1
        WHEN m.term_period = 'FORTNIGHT' THEN 0.5
        WHEN m.term_period = 'MONTH' THEN 0.230 -- 
        WHEN m.term_period = 'WEEKEND' THEN 3.5
      END AS weekly_multiplier,
      CASE
        WHEN n.amount_type = 'VALUE' THEN o.`value`
        WHEN o.`value` IS NOT NULL THEN o.`value` -- i.e when amount_type is SCALAR or RANGE
        ELSE n.amount_low -- if above is null return values recorded in alcohol_unit_numunitid_aurum
      END AS resolved_low,
      CASE
        WHEN n.amount_type = 'VALUE' THEN o.`value`
        WHEN o.`value` IS NOT NULL THEN o.`value` -- i.e when amount_type is SCALAR or RANGE
        ELSE n.amount_high -- if above is null return values recorded in alcohol_unit_numunitid_aurum
      END AS resolved_high
    FROM
      alcohol_observation AS o
      INNER JOIN aurum_oxcprd_001b.alcohol_unit_aurum AS m ON m.medcodeid = o.medcodeid
      LEFT JOIN aurum_oxcprd_001b.alcohol_unit_numunitid_aurum AS n ON n.numunitid = o.numunitid
  ),
  classified AS (
    SELECT
      r.*,
      CASE
        WHEN r.numunitid IS NULL THEN 'NUMUNIT_NULL'
        WHEN r.matched_numunitid IS NULL THEN 'NUMUNIT_NOT_ACCEPTED'
        WHEN r.term_has_unit = 0
        AND r.numunit_has_unit = 0 THEN 'UNIT_NOT_ESTABLISHED' -- used for codes like social drinker with 0 units - decision: remove.
        WHEN r.term_period IS NOT NULL
        AND r.numunit_period IS NOT NULL
        AND r.term_period <> r.numunit_period THEN 'PERIOD_CONFLICT'
        WHEN r.resolved_period IS NULL THEN 'PERIOD_NOT_ESTABLISHED' -- we accept if period is provided by only medcodeid or numunitid e.g medcodeid: alcohol consumption, numunitid: units/week
        WHEN r.amount_type = 'VALUE'
        AND r.`value` IS NULL THEN 'VALUE_NULL' -- null is not zero
        WHEN r.amount_type = 'SCALAR'
        AND r.`value` IS NOT NULL
        AND r.`value` <> r.amount_low -- similarly not equal to amount_high
        THEN 'VALUE_NOT_EQUAL_TO_NUMUNIT'
        WHEN r.amount_type = 'RANGE'
        AND r.`value` IS NOT NULL
        AND (
          r.`value` < r.amount_low
          OR r.`value` > r.amount_high
        ) THEN 'VALUE_OUTSIDE_NUMUNIT_RANGE'
        WHEN r.weekly_multiplier IS NULL THEN 'PERIOD_CONVERSION_MISSING'
        WHEN r.resolved_low < 0
        OR r.resolved_high < 0 THEN 'NEGATIVE_AMOUNT'
        WHEN r.resolved_low = 0
        AND r.resolved_high = 0
        AND r.zero_allowed = 0 THEN 'ZERO_NOT_ALLOWED'
        ELSE 'ACCEPT'
      END AS reason_code
    FROM
      resolved AS r
  )
SELECT
  c.patid,
  c.eventdate,
  c.medcodeid,
  c.`value`,
  c.numunitid,
  c.obstypeid,
  c.term,
  c.numunit_description,
  CASE
    WHEN c.reason_code = 'ACCEPT' THEN 'ACCEPT'
    ELSE 'REJECT'
  END AS status,
  c.reason_code,
  CASE
    WHEN c.reason_code = 'ACCEPT' THEN c.resolved_low * c.weekly_multiplier
  END AS weekly_units_low,
  CASE
    WHEN c.reason_code = 'ACCEPT' THEN c.resolved_high * c.weekly_multiplier
  END AS weekly_units_high
FROM
  classified AS c;

CREATE INDEX idx_patid ON aurum_oxcprd_001b.alcohol_units_observation_classified (patid, eventdate);

CREATE INDEX idx_numunitid ON aurum_oxcprd_001b.alcohol_units_observation_classified (numunitid);

-- create table from alcohol_observations where alc_category is in (aud, light-drinker (with units), heavy-drinker (with units)
-- non-drinker (we do not include 'alc_test')
CREATE TABLE alcohol_phenotype_observation ENGINE = InnoDB AS
SELECT
  ao.patid,
  ao.eventdate,
  ao.medcodeid,
  ao.obstypeid,
  ao.`value`,
  ao.numunitid,
  ao.term,
  ao.alc_category,
  ao.strict_phenotype
FROM
  alcohol_observation AS ao
WHERE
  ao.alc_category IN ('aud', 'light-drinker', 'heavy-drinker', 'non-drinker');
