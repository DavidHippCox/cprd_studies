-- Authored by David Hippisley-Cox
-- project: aurum_bmi
-- analysis plan version: NA
USE aurum_test;

CREATE TABLE aurum_bmi.numunit LIKE aurum_test.numunit;

INSERT INTO
  aurum_bmi.numunit
SELECT
  *
FROM
  aurum_test.numunit;

CALL extract_by_code_to_table (
  'observation',
  'aurum_bmi',
  'v0_bmi_codes_aurum',
  '1900-01-02',
  '2024-12-31',
  'patid,obsdate,medcodeid,value,numunitid,obstypeid',
  'bmi_observation',
  TRUE,
  TRUE
);

CALL extract_by_code_to_table (
  'observation',
  'aurum_bmi',
  'v0_weight_codes_aurum',
  '1900-01-02',
  '2024-12-31',
  'patid,obsdate,medcodeid,value,numunitid,obstypeid',
  'weight_observation',
  TRUE,
  TRUE
);

CALL extract_by_code_to_table (
  'observation',
  'aurum_bmi',
  'v0_height_codes_aurum',
  '1900-01-02',
  '2024-12-31',
  'patid,obsdate,medcodeid,value,numunitid,obstypeid',
  'height_observation',
  TRUE,
  TRUE
);

USE aurum_bmi;

CREATE INDEX idx_medcodeid_numunitid ON bmi_observation (medcodeid, numunitid);

CREATE INDEX idx_medcodeid_numunitid ON weight_observation (medcodeid, numunitid);

CREATE INDEX idx_medcodeid_numunitid ON height_observation (medcodeid, numunitid);

CREATE TABLE bmi_observation_summary AS
SELECT
  s.medcodeid,
  c.term AS medcodeid_term,
  s.numunitid,
  n.description AS numunitid_description,
  s.numunitid_count
FROM
  (
    SELECT
      medcodeid,
      numunitid,
      COUNT(*) AS numunitid_count
    FROM
      bmi_observation
    GROUP BY
      medcodeid,
      numunitid
  ) AS s
  INNER JOIN v0_bmi_codes_AURUM AS c ON c.medcodeid = s.medcodeid
  INNER JOIN numunit AS n ON n.numunitid = s.numunitid;

CREATE TABLE weight_observation_summary AS
SELECT
  s.medcodeid,
  c.term AS medcodeid_term,
  s.numunitid,
  n.description AS numunitid_description,
  s.numunitid_count
FROM
  (
    SELECT
      medcodeid,
      numunitid,
      COUNT(*) AS numunitid_count
    FROM
      weight_observation
    GROUP BY
      medcodeid,
      numunitid
  ) AS s
  INNER JOIN v0_weight_codes_AURUM AS c ON c.medcodeid = s.medcodeid
  INNER JOIN numunit AS n ON n.numunitid = s.numunitid;

CREATE TABLE height_observation_summary AS
SELECT
  s.medcodeid,
  c.term AS medcodeid_term,
  s.numunitid,
  n.description AS numunitid_description,
  s.numunitid_count
FROM
  (
    SELECT
      medcodeid,
      numunitid,
      COUNT(*) AS numunitid_count
    FROM
      height_observation
    GROUP BY
      medcodeid,
      numunitid
  ) AS s
  INNER JOIN v0_height_codes_AURUM AS c ON c.medcodeid = s.medcodeid
  INNER JOIN numunit AS n ON n.numunitid = s.numunitid;

--- export to csv---
SELECT
  'medcodeid',
  'medcodeid_term',
  'numunitid',
  'numunitid_description',
  'numunitid_count'
UNION ALL
SELECT
  medcodeid,
  medcodeid_term,
  numunitid,
  numunitid_description,
  numunitid_count
FROM
  bmi_observation_summary INTO OUTFILE '{{DATA_ROOT}}/mariadb-12.3.2-winx64/sql_scripts/aurum_bmi/bmi_observation_summary.csv' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';

SELECT
  'medcodeid',
  'medcodeid_term',
  'numunitid',
  'numunitid_description',
  'numunitid_count'
UNION ALL
SELECT
  *
FROM
  weight_observation_summary INTO OUTFILE '{{DATA_ROOT}}/mariadb-12.3.2-winx64/sql_scripts/aurum_bmi/weight_observation_summary.csv' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';

SELECT
  'medcodeid',
  'medcodeid_term',
  'numunitid',
  'numunitid_description',
  'numunitid_count'
UNION ALL
SELECT
  *
FROM
  height_observation_summary INTO OUTFILE '{{DATA_ROOT}}/mariadb-12.3.2-winx64/sql_scripts/aurum_bmi/height_observation_summary.csv' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';