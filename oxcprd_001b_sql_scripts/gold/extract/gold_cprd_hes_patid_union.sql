/*
CREATE INDEX idx_patid_eventdate on alcohol_clinical (patid, eventdate);
CREATE INDEX idx_patid_eventdate on dementia_clinical (patid, eventdate);
CREATE INDEX idx_medcode_eventdate on alcohol_clinical (medcode, eventdate);
CREATE INDEX idx_medcode_eventdate on dementia_clinical (medcode, eventdate);
*/

DROP TABLE IF EXISTS gold_oxcprd_001b.dementia_patids;

CREATE TABLE gold_oxcprd_001b.dementia_patids AS
SELECT
patid,
MIN(eventdate) AS eventdate
FROM (
-- cprd tables
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_clinical

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_referral

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_test

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_immunisation

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_drug_therapy
/*
UNION ALL
-- hes tables
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_hes_diagnosis_epi

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_hes_diagnosis_hosp

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_hes_primary_diag_hosp

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.dementia_hesop_clinical_apptdate
*/
) AS x
GROUP BY patid;

-- ALTER TABLE gold_oxcprd_001b.dementia_patids
-- ADD PRIMARY KEY (patid);


DROP TABLE IF EXISTS gold_oxcprd_001b.alcohol_patids;

CREATE TABLE gold_oxcprd_001b.alcohol_patids AS
SELECT
patid,
MIN(eventdate) AS eventdate
FROM (
-- cprd tables
SELECT patid, eventdate
FROM gold_oxcprd_001b.alcohol_clinical

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.alcohol_referral

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.alcohol_test

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.alcohol_immunisation

/*
UNION ALL
-- hes tables
SELECT patid, eventdate
FROM gold_oxcprd_001b.alcohol_hes_diagnosis_epi

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.alcohol_hes_diagnosis_hosp

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.alcohol_hes_primary_diag_hosp

UNION ALL
SELECT patid, eventdate
FROM gold_oxcprd_001b.alcohol_hesop_clinical_apptdate
*/
) AS x
GROUP BY patid;

-- ALTER TABLE gold_oxcprd_001b.alcohol_patids
-- ADD PRIMARY KEY (patid);

CREATE TABLE gold_oxcprd_001b.candidate_patids AS
SELECT
    d.patid,
    d.eventdate AS dementia_eventdate,
    a.eventdate AS alcohol_eventdate
FROM gold_oxcprd_001b.dementia_patids AS d
INNER JOIN gold_oxcprd_001b.alcohol_patids AS a
    ON a.patid = d.patid;