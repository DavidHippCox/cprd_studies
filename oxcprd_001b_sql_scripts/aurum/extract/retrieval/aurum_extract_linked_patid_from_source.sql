-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
USE aurum_linked;

CALL extract_linked_by_patid_to_table_default ('patient_2019_imd', 'aurum_oxcprd_001b');

CALL extract_linked_by_patid_to_table_default ('death_patient', 'aurum_oxcprd_001b');

CALL extract_linked_by_patid_to_table_default ('linkage_eligibility', 'aurum_oxcprd_001b');

CALL extract_linked_by_patid_to_table_default ('ethnicity_record', 'aurum_oxcprd_001b');

CALL extract_linked_by_patid_to_table_default ('hes_patient', 'aurum_oxcprd_001b');

CREATE TABLE aurum_oxcprd_001b.practice_imd
SELECT
  *
FROM
  aurum_linked.practice_imd;

CALL extract_linked_by_patid_to_table_default ('hes_diagnosis_epi', 'aurum_oxcprd_001b');

CALL extract_linked_by_patid_to_table_default ('hes_diagnosis_hosp', 'aurum_oxcprd_001b');

CALL extract_linked_by_patid_to_table_default ('hes_primary_diag_hosp', 'aurum_oxcprd_001b');

CALL extract_linked_by_patid_to_table_default ('hesop_clinical_apptdate', 'aurum_oxcprd_001b');
