-- done in source database gold
DELIMITER $$
CREATE PROCEDURE extract_table (IN p_source_table VARCHAR(64))
BEGIN DECLARE v_target_table VARCHAR(128);

SET
  v_target_table = CONCAT('', p_source_table);

CALL extract_by_patid_to_table (
  p_source_table,
  'gold_oxcprd_001b',
  'candidate_patids',
  '*',
  v_target_table,
  TRUE
);

END $$ DELIMITER;

CALL extract_table ('hes_diagnosis_epi');

CALL extract_table ('hes_diagnosis_hosp');

CALL extract_table ('hes_primary_diag_hosp');

CALL extract_table ('hesop_clinical');

CALL extract_table ('hesop_appointment');

CALL extract_table ('hes_patient');

CALL extract_table ('hes_hospital');

CALL extract_table ('hes_episodes');

CALL extract_table ('hes_procedures_epi');

CALL extract_table ('hes_acp');

CALL extract_table ('hes_ccare');

CALL extract_table ('hesop_patient');

CALL extract_table ('hesop_patient_pathway');

CALL extract_table ('hesop_operation');

CALL extract_table ('patient_imd');

CALL extract_table ('practiceImd');

CALL extract_table ('ons_death');