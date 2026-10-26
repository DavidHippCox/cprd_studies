-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_003
-- analysis plan version: NA
-- "candidate_patids" are patients that have aud any time thiamine_only anytime
USE aurum_test;

CALL extract_by_patid_to_table(
   'patient',
   'aurum_oxcprd_003',
   'candidate_patids',
   '*',
   'patient',
   TRUE,
   TRUE
);

USE aurum_linked;

CALL extract_linked_by_patid_to_table_default('patient_2019_imd', 'aurum_oxcprd_003');
CALL extract_linked_by_patid_to_table_default('death_patient', 'aurum_oxcprd_003');
CALL extract_linked_by_patid_to_table_default('linkage_eligibility', 'aurum_oxcprd_003');
CALL extract_linked_by_patid_to_table_default('ethnicity_record', 'aurum_oxcprd_003');

-- CREATE TABLE aurum_oxcprd_003.practice_imd SELECT * FROM  aurum_linked.practice_imd;

