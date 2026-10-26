-- Authored by David Hippisley-Cox
-- project: aurum_alcohol
-- analysis plan version: NA
USE aurum_linked;

-- extract alcohol from HES_APC, HESOP and CPRD AURUM observation
-- alcohol hes
CALL extract_linked_by_code_to_table (
  'hes_diagnosis_epi',
  'aurum_alcohol',
  'alcohol_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,epistart,ICD',
  'alcohol_hes_diagnosis_epi',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hes_diagnosis_hosp',
  'aurum_alcohol',
  'alcohol_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,admidate,ICD',
  'alcohol_hes_diagnosis_hosp',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hes_primary_diag_hosp',
  'aurum_alcohol',
  'alcohol_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,admidate,ICD_PRIMARY',
  'alcohol_hes_primary_diag_hosp',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hesop_clinical_apptdate',
  'aurum_alcohol',
  'alcohol_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,apptdate,icd',
  'alcohol_hesop_clinical_apptdate',
  TRUE
);

-- alcohol observation AURUM
USE aurum_test;

CALL extract_by_code_to_table (
  'observation',
  'aurum_alcohol',
  'v0_alcohol_codes_aurum',
  '1900-01-02',
  '2024-12-31',
  'patid,obsdate,medcodeid,value,numunitid,obstypeid',
  'alcohol_observation',
  TRUE,
  TRUE
);

-- CHANGE DATABASE -- 
USE aurum_alcohol;

CREATE INDEX idx_patid ON alcohol_hes_diagnosis_epi (patid);

CREATE INDEX idx_icd10_date ON alcohol_hes_diagnosis_epi (icd, epistart);

-- alcohol_hes_diagnosis_hosp
CREATE INDEX idx_patid ON alcohol_hes_diagnosis_hosp (patid);

CREATE INDEX idx_icd10_date ON alcohol_hes_diagnosis_hosp (icd, admidate);

-- alcohol_hes_primary_diag_hosp
CREATE INDEX idx_patid ON alcohol_hes_primary_diag_hosp (patid);

CREATE INDEX idx_icd10_date ON alcohol_hes_primary_diag_hosp (ICD_PRIMARY, admidate);

-- alcohol_hesop_clinical_apptdate
CREATE INDEX idx_patid ON alcohol_hesop_clinical_apptdate (patid);

CREATE INDEX idx_icd10_date ON alcohol_hesop_clinical_apptdate (icd, apptdate);

-- alcohol_observation
CREATE INDEX idx_patid ON alcohol_observation (patid);

CREATE INDEX idx_medcodeid_obsdate ON alcohol_observation (medcodeid, obsdate);

-- NOTE: MULTIPLE ALCOHOL/EVENTS ON THE SAME DATE WILL RESULT IN ONLY 1 RECORDED. 
-- alcohol patids
CREATE TABLE aurum_alcohol.alcohol_patids AS
SELECT
  patid,
  MIN(eventdate) AS earliest_eventdate
FROM
  (
    SELECT
      patid,
      obsdate AS eventdate
    FROM
      aurum_alcohol.alcohol_observation
    UNION ALL
    SELECT
      patid,
      epistart AS eventdate
    FROM
      aurum_alcohol.alcohol_hes_diagnosis_epi
    UNION ALL
    SELECT
      patid,
      admidate AS eventdate
    FROM
      aurum_alcohol.alcohol_hes_diagnosis_hosp
    UNION ALL
    SELECT
      patid,
      admidate AS eventdate
    FROM
      aurum_alcohol.alcohol_hes_primary_diag_hosp
    UNION ALL
    SELECT
      patid,
      apptdate AS eventdate
    FROM
      aurum_alcohol.alcohol_hesop_clinical_apptdate
  ) AS x
GROUP BY
  patid;

ALTER TABLE aurum_alcohol.alcohol_patids
ADD PRIMARY KEY (patid);

-- run this after cprd_alcohol_units.sql!!!
-- AUD
CREATE TABLE aurum_alcohol.aud_from_alcohol_units_patids AS
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

ALTER TABLE aurum_alcohol.aud_from_alcohol_units_patids
ADD PRIMARY KEY (patid);

CREATE INDEX idx_medcodeid_obsdate ON aurum_alcohol.aud_from_alcohol_units_patids (medcodeid, obsdate);

DROP TABLE IF EXISTS aurum_alcohol.aud_from_medcode_patids;

CREATE TABLE aurum_alcohol.aud_from_medcode_patids AS
SELECT
  o.patid,
  o.medcodeid,
  MIN(o.obsdate) AS earliest_obsdate
FROM
  aurum_alcohol.alcohol_observation AS o
  JOIN aurum_alcohol.v0_alcohol_codes_aurum AS c ON c.medcodeid = o.medcodeid
WHERE
  c.alc_category = 'aud'
GROUP BY
  o.patid;

ALTER TABLE aurum_alcohol.aud_from_medcode_patids
ADD PRIMARY KEY (patid);

CREATE INDEX idx_medcodeid_obsdate ON aurum_alcohol.aud_from_medcode_patids (medcodeid, earliest_obsdate);

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

-- add indexes for aud_hes tables if you desire
CREATE TABLE aurum_alcohol.aud_hes_patids AS
SELECT
  patid,
  icd,
  MIN(eventdate) AS earliest_eventdate
FROM
  (
    SELECT
      patid,
      icd,
      epistart AS eventdate
    FROM
      aurum_alcohol.aud_hes_diagnosis_epi
    UNION ALL
    SELECT
      patid,
      icd,
      admidate AS eventdate
    FROM
      aurum_alcohol.aud_hes_diagnosis_hosp
    UNION ALL
    SELECT
      patid,
      icd_primary AS icd,
      admidate AS eventdate
    FROM
      aurum_alcohol.aud_hes_primary_diag_hosp
    UNION ALL
    SELECT
      patid,
      icd,
      apptdate AS eventdate
    FROM
      aurum_alcohol.aud_hesop_clinical_apptdate
  ) AS x
GROUP BY
  patid;

ALTER TABLE aurum_alcohol.aud_hes_patids
ADD PRIMARY KEY (patid);

CREATE INDEX idx_icd10_date ON aurum_alcohol.aud_hes_patids (icd, eventdate);

CREATE TABLE aurum_alcohol.aud_patids AS
SELECT
  patid,
  MIN(eventdate) AS earliest_eventdate
FROM
  (
    SELECT
      patid,
      earliest_eventdate AS eventdate
    FROM
      aurum_alcohol.aud_hes_patids
    UNION ALL
    SELECT
      patid,
      earliest_obsdate AS eventdate
    FROM
      aurum_alcohol.aud_from_medcode_patids
    UNION ALL
    SELECT
      patid,
      earliest_obsdate AS eventdate
    FROM
      aurum_alcohol.aud_from_alcohol_units_patids
  ) AS x
GROUP BY
  patid;

ALTER TABLE aurum_alcohol.aud_patids
ADD PRIMARY KEY (patid);
