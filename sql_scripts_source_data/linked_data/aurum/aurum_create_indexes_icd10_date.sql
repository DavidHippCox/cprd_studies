-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
-- idx_icd10_date

CREATE INDEX idx_icd10_date on   hes_diagnosis_epi       (ICD, epistart);
CREATE INDEX idx_icd10_date on   hes_diagnosis_hosp      (ICD, admidate);

CREATE INDEX idx_icd10_date on   hes_primary_diag_hosp   (ICD_PRIMARY, admidate);

CREATE INDEX idx_icd10_date on   hesop_clinical_apptdate          (icd, apptdate); -- post join form hesop_appointment

