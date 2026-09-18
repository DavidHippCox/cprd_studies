SET
  SESSION foreign_key_checks = 0;

ALTER TABLE gold_linked.death_patient DISCARD TABLESPACE;

ALTER TABLE gold_linked.ethnicity_record DISCARD TABLESPACE;

ALTER TABLE gold_linked.gold_linkage_coverage_march_2026 DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesae_attendance DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesae_diagnosis DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesae_hrg DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesae_investigation DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesae_pathway DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesae_patient DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesae_treatment DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesop_appointment DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesop_clinical DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesop_clinical_apptdate DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesop_operation DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesop_patient DISCARD TABLESPACE;

ALTER TABLE gold_linked.hesop_patient_pathway DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_ccare DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_diagnosis_epi DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_diagnosis_hosp DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_episodes DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_hospital DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_hrg DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_maternity DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_patient DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_primary_diag_hosp DISCARD TABLESPACE;

ALTER TABLE gold_linked.hes_procedures_epi DISCARD TABLESPACE;

ALTER TABLE gold_linked.linkage_eligibility DISCARD TABLESPACE;

ALTER TABLE gold_linked.patient_2019_imd DISCARD TABLESPACE;

ALTER TABLE gold_linked.practice_imd DISCARD TABLESPACE;

--- after copying table space
SET
  SESSION foreign_key_checks = 0;

ALTER TABLE gold_linked.death_patient IMPORT TABLESPACE;

ALTER TABLE gold_linked.ethnicity_record IMPORT TABLESPACE;

ALTER TABLE gold_linked.gold_linkage_coverage_march_2026 IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesae_attendance IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesae_diagnosis IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesae_hrg IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesae_investigation IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesae_pathway IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesae_patient IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesae_treatment IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesop_appointment IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesop_clinical IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesop_clinical_apptdate IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesop_operation IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesop_patient IMPORT TABLESPACE;

ALTER TABLE gold_linked.hesop_patient_pathway IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_ccare IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_diagnosis_epi IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_diagnosis_hosp IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_episodes IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_hospital IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_hrg IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_maternity IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_patient IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_primary_diag_hosp IMPORT TABLESPACE;

ALTER TABLE gold_linked.hes_procedures_epi IMPORT TABLESPACE;

ALTER TABLE gold_linked.linkage_eligibility IMPORT TABLESPACE;

ALTER TABLE gold_linked.patient_2019_imd IMPORT TABLESPACE;

ALTER TABLE gold_linked.practice_imd IMPORT TABLESPACE;
