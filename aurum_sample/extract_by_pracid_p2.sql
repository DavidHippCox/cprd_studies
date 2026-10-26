-- Authored by David Hippisley-Cox
-- project: aurum_sample
-- analysis plan version: NA
-- done in source database aurum_test;
USE aurum_test;


CALL extract_by_patid_to_table(
   'drugissue',
   'aurum_dev',
   'patient',
   '*',
   'drugissue',
   TRUE,
   FALSE
);

CALL extract_by_patid_to_table(
    'observation',
    'aurum_dev',
    'patient',
    '*',
    'observation',
    TRUE,
   FALSE
);

CALL extract_by_patid_to_table(
   'consultation',
   'aurum_dev',
   'patient',
   '*',
   'consultation',
   TRUE,
   FALSE
);

/*
CALL extract_by_patid_to_table(
   'referral',
   'aurum_dev',
   'patient',
   '*',
   'referral',
   TRUE,
   FALSE
);


CALL extract_by_patid_to_table(
   'problem',
   'aurum_dev',
   'patient',
   '*',
   'problem',
   TRUE,
   FALSE
);
*/


USE aurum_linked;

/*
CREATE TABLE aurum_dev.practice_imd AS
SELECT t1.*
FROM aurum_linked.practice_imd AS t1
INNER JOIN aurum_dev.practice AS t2
    ON t1.pracid = t2.pracid;
*/


CALL extract_linked_by_patid_to_table(
    'death_patient', 'aurum_dev', 'patient', '*', 'death_patient', TRUE
);

CALL extract_linked_by_patid_to_table(
    'ethnicity_record', 'aurum_dev', 'patient', '*', 'ethnicity_record', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_ccare', 'aurum_dev', 'patient', '*', 'hes_ccare', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_diagnosis_epi', 'aurum_dev', 'patient', '*',
    'hes_diagnosis_epi', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_diagnosis_hosp', 'aurum_dev', 'patient', '*',
    'hes_diagnosis_hosp', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_episodes', 'aurum_dev', 'patient', '*', 'hes_episodes', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_hospital', 'aurum_dev', 'patient', '*', 'hes_hospital', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_hrg', 'aurum_dev', 'patient', '*', 'hes_hrg', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_maternity', 'aurum_dev', 'patient', '*', 'hes_maternity', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_patient', 'aurum_dev', 'patient', '*', 'hes_patient', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_primary_diag_hosp', 'aurum_dev', 'patient', '*',
    'hes_primary_diag_hosp', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hes_procedures_epi', 'aurum_dev', 'patient', '*',
    'hes_procedures_epi', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesae_attendance', 'aurum_dev', 'patient', '*',
    'hesae_attendance', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesae_diagnosis', 'aurum_dev', 'patient', '*',
    'hesae_diagnosis', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesae_hrg', 'aurum_dev', 'patient', '*', 'hesae_hrg', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesae_investigation', 'aurum_dev', 'patient', '*',
    'hesae_investigation', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesae_pathway', 'aurum_dev', 'patient', '*',
    'hesae_pathway', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesae_patient', 'aurum_dev', 'patient', '*',
    'hesae_patient', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesae_treatment', 'aurum_dev', 'patient', '*',
    'hesae_treatment', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesop_appointment', 'aurum_dev', 'patient', '*',
    'hesop_appointment', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesop_clinical', 'aurum_dev', 'patient', '*',
    'hesop_clinical', TRUE
);

CALL extract_linked_by_patid_to_table(
    'hesop_clinical_apptdate', 'aurum_dev', 'patient', '*',
    'hesop_clinical_apptdate', TRUE
);





CALL extract_linked_by_patid_to_table(
    'hesop_operation', 'aurum_dev', 'patient', '*',
    'hesop_operation', TRUE
);
/*
CALL extract_linked_by_patid_to_table(
    'hesop_patient', 'aurum_dev', 'patient', '*',
    'hesop_patient', TRUE
);
*/
CALL extract_linked_by_patid_to_table(
    'hesop_patient_pathway', 'aurum_dev', 'patient', '*',
    'hesop_patient_pathway', TRUE
);

CALL extract_linked_by_patid_to_table(
    'linkage_eligibility', 'aurum_dev', 'patient', '*',
    'linkage_eligibility', TRUE
);

CALL extract_linked_by_patid_to_table(
    'patient_2019_imd', 'aurum_dev', 'patient', '*',
    'patient_2019_imd', TRUE
);

