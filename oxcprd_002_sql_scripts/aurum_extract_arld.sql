-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_002
-- analysis plan version: NA
USE aurum_test;

CALL extract_by_code_to_table (
  'observation',
  'aurum_arld',
  'v1_arld_codes_aurum',
  '1900-01-02',
  '2024-12-31',
  'patid,obsdate,medcodeid',
  'arld_observation',
  TRUE,
  TRUE
);

/*
select count(distinct patid) from arld_observation; -- 114742

select count(distinct patid) from patient; -- 116456

select count(distinct patid) from (select patid from patient union select patid from arld_observation) as x ; -- 116456

difference is due to date filter not extracting from merging practices.

the tables in aurum_arld, due to time constraints, 
were built from extrating from the events from observation txt files directly. 
All records were then extracted from cprd txt files and then imported.
*/