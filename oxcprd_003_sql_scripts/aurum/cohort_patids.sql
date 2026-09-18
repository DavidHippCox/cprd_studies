USE aurum_oxcprd_003;

DROP TABLE IF EXISTS aurum_oxcprd_003.aud_patids;

CREATE TABLE aurum_oxcprd_003.aud_patids LIKE aurum_alcohol.aud_patids
INSERT INTO aurum_oxcprd_003.aud_patids
SELECT *
FROM aurum_alcohol.aud_patids;

-- import in tables used to create aud_patids for reference.
DROP TABLE IF EXISTS aurum_oxcprd_003.aud_hes_patids;

CREATE TABLE aurum_oxcprd_003.aud_hes_patids LIKE aurum_alcohol.aud_hes_patids
INSERT INTO aurum_oxcprd_003.aud_hes_patids
SELECT *
FROM aurum_alcohol.aud_hes_patids;

DROP TABLE IF EXISTS aurum_oxcprd_003.aud_from_medcode_patids;

CREATE TABLE aurum_oxcprd_003.aud_from_medcode_patids LIKE aurum_alcohol.aud_from_medcode_patids
INSERT INTO aurum_oxcprd_003.aud_from_medcode_patids
SELECT *
FROM aurum_alcohol.aud_from_medcode_patids;

DROP TABLE IF EXISTS aurum_oxcprd_003.aud_from_alcohol_units_patids;

CREATE TABLE aurum_oxcprd_003.aud_from_alcohol_units_patids LIKE aurum_alcohol.aud_from_alcohol_units_patids
INSERT INTO aurum_oxcprd_003.aud_from_alcohol_units_patids
SELECT *
FROM aurum_alcohol.aud_from_alcohol_units_patids;



CREATE TABLE candidate_patids AS 
SELECT
    a.patid,
    a.earliest_eventdate  AS aud_eventdate,
    t.earliest_issuedate  AS thiamine_eventdate
FROM aud_patids AS a
INNER JOIN thiamine_only_patids AS t
    ON t.patid = a.patid;

CREATE TABLE aud_thiamine_only_patids_30d
SELECT *
FROM candidate_patids
WHERE aud_eventdate<thiamine_eventdate and DATEDIFF(thiamine_eventdate, aud_eventdate) <= 30;

CREATE TABLE aud_thiamine_only_patids_abs_30d
SELECT *
FROM candidate_patids
WHERE DATEDIFF(thiamine_eventdate, aud_eventdate) BETWEEN -30 AND 30;



CREATE TABLE analysis_thiamine_cohort AS
SELECT
    '30d' AS cohort,
    patid,
    aud_eventdate AS t0,
    thiamine_eventdate AS seed_thiamine_date,
    0 AS window_start_day,
    30 AS window_end_day
FROM aud_thiamine_only_patids_30d

UNION ALL

SELECT
    'abs_30d' AS cohort,
    patid,
    aud_eventdate AS t0,
    thiamine_eventdate AS seed_thiamine_date,
    -30 AS window_start_day,
    30 AS window_end_day
FROM aud_thiamine_only_patids_abs_30d;

ALTER TABLE analysis_thiamine_cohort
    ADD PRIMARY KEY (cohort, patid),
    ADD INDEX ix_patid (patid),
    ADD INDEX ix_t0 (cohort, t0);





CREATE TABLE analysis_thiamine_baseline AS
SELECT
    c.cohort,
    c.patid,
    c.t0,
    c.seed_thiamine_date,
    c.window_start_day,
    c.window_end_day,

    p.pracid,
    p.gender,
    p.yob,
    p.regstartdate,
    p.regenddate,
    p.acceptable,

    le.linkyear,
    le.hes_apc_e,
    le.ons_death_e,
    le.lsoa_e,
    le.hes_op_e,
    le.hes_ae_e,
    le.hes_did_e,

    imd.e2019_imd_20,
    eth.ethnic_6,

    p.patid IS NOT NULL AS patient_record_available,
    le.patid IS NOT NULL AS linkage_record_available,
    imd.patid IS NOT NULL AS imd_record_available,
    eth.patid IS NOT NULL AS ethnicity_record_available

FROM analysis_thiamine_cohort AS c

LEFT JOIN patient AS p
    ON p.patid = c.patid

LEFT JOIN linkage_eligibility AS le
    ON le.patid = c.patid

LEFT JOIN patient_2019_imd AS imd
    ON imd.patid = c.patid

LEFT JOIN ethnicity_record AS eth
    ON eth.patid = c.patid;

ALTER TABLE analysis_thiamine_baseline
    ADD PRIMARY KEY (cohort, patid),
    ADD INDEX ix_baseline_patid (patid),
    ADD INDEX ix_baseline_t0 (cohort, t0);





