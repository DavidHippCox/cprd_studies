-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_002
-- analysis plan version: NA
-- once performing inner join of patids to create alcohol_units_observation_classified table and copying the lookups from aurum_alcohol 
-- we do this export (easiest considering size of data)

-- from source database
use aurum_arld;


SELECT
  *
FROM alcohol_unit_aurum
INTO OUTFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_unit_aurum.csv'
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n';

SELECT
  *
FROM alcohol_unit_numunitid_aurum
INTO OUTFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_unit_numunitid_aurum.csv'
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n';

SELECT
  *
FROM alcohol_units_observation_classified
INTO OUTFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_units_observation_classified.csv'
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n';

