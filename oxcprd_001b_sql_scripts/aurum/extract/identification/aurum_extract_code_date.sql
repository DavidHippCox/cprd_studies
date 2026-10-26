-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_001b
-- analysis plan version: v2
USE aurum_test;

CALL extract_by_code_to_table (
  'observation',
  'aurum_oxcprd_001b',
  'v0_dementia_codes_aurum',
  '1998-01-02',
  '2024-12-31',
  'patid,obsdate,medcodeid,obstypeid',
  'dementia_observation',
  TRUE,
  TRUE
);

CALL extract_by_code_to_table (
  'drugissue',
  'aurum_oxcprd_001b',
  'v0_dementia_drug_aurum',
  '1998-01-02',
  '2024-12-31',
  'patid,issuedate,prodcodeid',
  'dementia_drug_drugissue',
  TRUE,
  TRUE
);

CALL extract_by_code_to_table (
  'observation',
  'aurum_oxcprd_001b',
  'v0_alcohol_codes_aurum',
  '1900-01-02',
  '2024-12-31',
  'patid,obsdate,medcodeid,value,numunitid,obstypeid',
  'alcohol_observation',
  TRUE,
  TRUE
);

USE aurum_oxcprd_001b;

CREATE INDEX idx_patid ON dementia_observation (patid);

CREATE INDEX idx_medcode_obsdate ON dementia_observation (medcodeid, obsdate);

CREATE INDEX idx_patid ON dementia_drug_drugissue (patid);

CREATE INDEX idx_medcode_obsdate ON dementia_drug_drugissue (prodcodeid, issuedate);

CREATE INDEX idx_patid ON alcohol_observation (patid);

CREATE INDEX idx_medcode_obsdate ON alcohol_observation (medcodeid, obsdate);
