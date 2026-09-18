USE aurum_test;

CREATE TABLE aurum_smoking.numunit LIKE aurum_test.numunit;

INSERT INTO
  aurum_smoking.numunit
SELECT
  *
FROM
  aurum_test.numunit;

CALL extract_by_code_to_table (
  'observation',
  'aurum_smoking',
  'v0_smoking_codes_aurum',
  '1900-01-02',
  '2024-12-31',
  'patid,obsdate,medcodeid,value,numunitid,obstypeid',
  'smoking_observation',
  TRUE,
  TRUE
);

USE aurum_smoking;

CREATE INDEX idx_medcodeid_numunitid ON smoking_observation (medcodeid, numunitid);

CREATE TABLE smoking_observation_summary AS
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
      smoking_observation
    GROUP BY
      medcodeid,
      numunitid
  ) AS s
  INNER JOIN v0_smoking_codes_AURUM AS c ON c.medcodeid = s.medcodeid
  INNER JOIN numunit AS n ON n.numunitid = s.numunitid;

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
  smoking_observation_summary INTO OUTFILE '{{DATA_ROOT}}/mariadb-12.3.2-winx64/sql_scripts/aurum_smoking/smoking_observation_summary.csv' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';