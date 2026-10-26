-- Authored by David Hippisley-Cox
-- project: aurum_sample
-- analysis plan version: NA
-- 
/*
pracids were generated from this query:
SELECT *
FROM practice
WHERE pracid NOT IN (
    20024, 20469, 20803, 20036, 21112, 21444, 20487, 20804,
    20091, 21118, 21451, 20552, 20822, 20171, 21172, 21529,
    20554, 20868, 20178, 21173, 21553, 20640, 20908, 20202,
    21277, 21558, 20717, 20912, 20254, 21281, 21585, 20734,
    20996, 20389, 21331, 20737, 21001, 20430, 21334, 20740,
    21015, 20452, 21390, 20790, 21078, 21430
)
ORDER BY lcd DESC
LIMIT 100;
*/
-- these pracids should be excluded from analyses 
-- (by CPRD recommendation - AURUM Specification)

-- TOTAL NUMBER OF PATIENTS 2,506,802

USE aurum_dev;

CREATE TABLE aurum_dev.practice like aurum_test.practice;

LOAD DATA INFILE '{{DATA_ROOT}}/mariadb-12.3.2-winx64/sql_scripts/aurum_sample/sample_pracids.txt'
INTO TABLE practice
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    pracid,
    @lcd,
    @uts,
    @region
)
SET
    lcd = NULLIF(@lcd, ''),
    uts = NULLIF(@uts, ''),
    region = NULLIF(@region, '');
  
-- assumption that we are getting patids with 
-- their most recent practice in sample_pracids.txt
-- to check: do patids have non-unique pracids in observation?
-- ANSWER: 
CREATE TABLE aurum_dev.patient AS 
SELECT t1.*
FROM aurum_test.patient AS t1
INNER JOIN aurum_dev.practice AS t2
    ON t1.pracid = t2.pracid;

ALTER TABLE ADD PRIMARY KEY (patid);


CREATE TABLE aurum_dev.staff AS
SELECT t1.*
FROM aurum_test.staff AS t1
INNER JOIN aurum_dev.practice AS t2
    ON t1.pracid = t2.pracid;

    