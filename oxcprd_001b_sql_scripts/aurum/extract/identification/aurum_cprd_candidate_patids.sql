-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
USE aurum_oxcprd_001b;

DROP TABLE IF EXISTS aurum_oxcprd_001b.dementia_patids;

CREATE TABLE aurum_oxcprd_001b.dementia_patids AS
SELECT
  patid,
  MIN(eventdate) AS eventdate
FROM
  (
    SELECT
      patid,
      obsdate AS eventdate
    FROM
      aurum_oxcprd_001b.dementia_observation
    UNION ALL
    SELECT
      patid,
      issuedate AS eventdate
    FROM
      aurum_oxcprd_001b.dementia_drug_drugissue
    UNION ALL
    SELECT
      patid,
      epistart AS eventdate
    FROM
      aurum_oxcprd_001b.dementia_hes_diagnosis_epi
    UNION ALL
    SELECT
      patid,
      admidate AS eventdate
    FROM
      aurum_oxcprd_001b.dementia_hes_diagnosis_hosp
    UNION ALL
    SELECT
      patid,
      admidate AS eventdate
    FROM
      aurum_oxcprd_001b.dementia_hes_primary_diag_hosp
    UNION ALL
    SELECT
      patid,
      apptdate AS eventdate
    FROM
      aurum_oxcprd_001b.dementia_hesop_clinical_apptdate
  ) AS x
GROUP BY
  patid;

ALTER TABLE aurum_oxcprd_001b.dementia_patids
ADD PRIMARY KEY (patid);

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

DROP TABLE IF EXISTS aurum_oxcprd_001b.candidate_patids
CREATE TABLE aurum_oxcprd_001b.candidate_patids AS
SELECT
  d.patid,
  d.eventdate AS dementia_mci_eventdate,
  a.eventdate AS alcohol_eventdate
FROM
  aurum_oxcprd_001b.dementia_patids AS d
  INNER JOIN aurum_oxcprd_001b.alcohol_patids AS a ON a.patid = d.patid;
