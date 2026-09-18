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

DROP TABLE IF EXISTS aurum_oxcprd_001b.alcohol_patids;

CREATE TABLE aurum_oxcprd_001b.alcohol_patids LIKE aurum_alcohol.alcohol_patids
INSERT INTO
  aurum_oxcprd_001b.alcohol_patids
SELECT
  *
FROM
  aurum_alcohol.alcohol_patids;

DROP TABLE IF EXISTS aurum_oxcprd_001b.candidate_patids
CREATE TABLE aurum_oxcprd_001b.candidate_patids AS
SELECT
  d.patid,
  d.eventdate AS dementia_eventdate,
  a.eventdate AS alcohol_eventdate
FROM
  aurum_oxcprd_001b.dementia_patids AS d
  INNER JOIN aurum_oxcprd_001b.alcohol_patids AS a ON a.patid = d.patid;

-- additionally, should copy over all hes aud events (F.10 is alcohol intoxification with no unit amounts so we only use aud codes)
CREATE TABLE aurum_oxcprd_001b.aud_hes_diagnosis_epi LIKE aurum_alcohol.aud_hes_diagnosis_epi;

INSERT INTO
  aurum_oxcprd_001b.aud_hes_diagnosis_epi
SELECT
  h.*
FROM
  aurum_alcohol.aud_hes_diagnosis_epi AS h
  INNER JOIN aurum_oxcprd_001b.candidate_patids AS c ON h.patid = c.patid;

CREATE TABLE aurum_oxcprd_001b.aud_hes_diagnosis_hosp LIKE aurum_alcohol.aud_hes_diagnosis_hosp;

INSERT INTO
  aurum_oxcprd_001b.aud_hes_diagnosis_hosp
SELECT
  h.*
FROM
  aurum_alcohol.aud_hes_diagnosis_hosp AS h
  INNER JOIN aurum_oxcprd_001b.candidate_patids AS c ON h.patid = c.patid;

CREATE TABLE aurum_oxcprd_001b.aud_hes_primary_diag_hosp LIKE aurum_alcohol.aud_hes_primary_diag_hosp;

INSERT INTO
  aurum_oxcprd_001b.aud_hes_primary_diag_hosp
SELECT
  h.*
FROM
  aurum_alcohol.aud_hes_primary_diag_hosp AS h
  INNER JOIN aurum_oxcprd_001b.candidate_patids AS c ON h.patid = c.patid;

CREATE TABLE aurum_oxcprd_001b.aud_hesop_clinical_apptdate LIKE aurum_alcohol.aud_hesop_clinical_apptdate;

INSERT INTO
  aurum_oxcprd_001b.aud_hesop_clinical_apptdate
SELECT
  h.*
FROM
  aurum_alcohol.aud_hesop_clinical_apptdate AS h
  INNER JOIN aurum_oxcprd_001b.candidate_patids AS c ON h.patid = c.patid;
