-- Authored by David Hippisley-Cox
-- project: aurum_alcohol
-- analysis plan version: NA
-- refer to script cprd_alcohol_units.sql
-- no longer needed as defined in aurum_alcohol database instead (extract data from aurum_alcohol instead)
DROP TABLE IF EXISTS aurum_oxcprd_001b.aud_from_alcohol_units_patids;

CREATE TABLE aurum_oxcprd_001b.aud_from_alcohol_units_patids AS
WITH
  filtered AS (
    SELECT
      c.patid,
      c.obsdate,
      c.medcodeid,
      c.weekly_units_low,
      c.weekly_units_high
    FROM
      alcohol_units_observation_classified AS c
      INNER JOIN aurum_test.patient AS p ON p.patid = c.patid
    WHERE
      c.status = 'accept'
      AND (
        (
          p.gender = 1
          AND c.weekly_units_low > 50
        )
        OR (
          p.gender = 2
          AND c.weekly_units_low > 35
        )
      )
  )
SELECT
  patid,
  MIN(obsdate) AS earliest_obsdate,
  medcodeid,
  weekly_units_low,
  weekly_units_high
FROM
  filtered
GROUP BY
  patid;

DROP TABLE IF EXISTS aurum_oxcprd_001b.aud_from_medcode_patids;

CREATE TABLE aurum_oxcprd_001b.aud_from_medcode_patids AS
WITH
  filtered AS (
    SELECT
      o.patid,
      o.obsdate,
      o.medcodeid
    FROM
      aurum_oxcprd_001b.alcohol_observation AS o
      INNER JOIN aurum_oxcprd_001b.v0_alcohol_codes_aurum AS c ON c.medcodeid = o.medcodeid
    WHERE
      c.alc_category = 'aud'
  ),
  earliest AS (
    SELECT
      patid,
      MIN(obsdate) AS earliest_obsdate
    FROM
      filtered
    GROUP BY
      patid
  )
SELECT
  f.patid,
  f.obsdate,
  f.medcodeid
FROM
  filtered AS f
  INNER JOIN earliest AS e ON e.patid = f.patid
  AND e.earliest_obsdate = f.obsdate;

CREATE TABLE aud_hes_diagnosis_epi AS
SELECT
  *
FROM
  alcohol_hes_diagnosis_epi
WHERE
  icd <> 'F10.0';

CREATE TABLE aud_hesop_clinical_apptdate AS
SELECT
  *
FROM
  alcohol_hesop_clinical_apptdate
WHERE
  icd <> 'F10.0';

CREATE TABLE aud_hes_diagnosis_hosp AS
SELECT
  *
FROM
  alcohol_hes_diagnosis_hosp
WHERE
  icd <> 'F10.0';

CREATE TABLE aud_hes_primary_diag_hosp AS
SELECT
  *
FROM
  alcohol_hes_primary_diag_hosp
WHERE
  icd_primary <> 'F10.0';

CREATE TABLE aurum_oxcprd_001b.aud_hes_patids AS
SELECT
  patid,
  icd,
  MIN(eventdate) AS eventdate
FROM
  (
    SELECT
      patid,
      icd,
      epistart AS eventdate
    FROM
      aurum_oxcprd_001b.aud_hes_diagnosis_epi
    UNION ALL
    SELECT
      patid,
      icd,
      admidate AS eventdate
    FROM
      aurum_oxcprd_001b.aud_hes_diagnosis_hosp
    UNION ALL
    SELECT
      patid,
      icd_primary AS icd,
      admidate AS eventdate
    FROM
      aurum_oxcprd_001b.aud_hes_primary_diag_hosp
    UNION ALL
    SELECT
      patid,
      icd,
      apptdate AS eventdate
    FROM
      aurum_oxcprd_001b.aud_hesop_clinical_apptdate
  ) AS x
GROUP BY
  patid;

CREATE TABLE aurum_oxcprd_001b.aud_patids AS
SELECT
  patid,
  MIN(eventdate) AS earliest_evendate
FROM
  (
    SELECT
      patid,
      eventdate
    FROM
      aurum_oxcprd_001b.aud_hes_patids
    UNION ALL
    SELECT
      patid,
      obsdate AS eventdate -- should rename obsdate to earliest_obsdate
    FROM
      aurum_oxcprd_001b.aud_from_medcode_patids
    UNION ALL
    SELECT
      patid,
      earliest_obsdate AS eventdate
    FROM
      aurum_oxcprd_001b.aud_from_alcohol_units_patids
  ) AS x
GROUP BY
  patid;
