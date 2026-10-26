-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
-- idx_patid

-- CREATE INDEX idx_patid on   death_patient           (patid); 
-- CREATE INDEX idx_patid on   ethnicity_record        (patid);
CREATE INDEX idx_patid on   hes_ccare               (patid);
CREATE INDEX idx_patid on   hes_diagnosis_epi       (patid);
CREATE INDEX idx_patid on   hes_diagnosis_hosp      (patid);
CREATE INDEX idx_patid on   hes_episodes            (patid);
CREATE INDEX idx_patid on   hes_hospital            (patid);
CREATE INDEX idx_patid on   hes_hrg                 (patid);
CREATE INDEX idx_patid on   hes_maternity           (patid);
CREATE INDEX idx_patid on   hes_patient             (patid);
CREATE INDEX idx_patid on   hes_primary_diag_hosp   (patid);
CREATE INDEX idx_patid on   hes_procedures_epi      (patid);
CREATE INDEX idx_patid on   hesae_attendance        (patid);
CREATE INDEX idx_patid on   hesae_diagnosis         (patid);
CREATE INDEX idx_patid on   hesae_hrg               (patid);
CREATE INDEX idx_patid on   hesae_investigation     (patid);
CREATE INDEX idx_patid on   hesae_pathway           (patid);
CREATE INDEX idx_patid on   hesae_patient           (patid);
CREATE INDEX idx_patid on   hesae_treatment         (patid);
CREATE INDEX idx_patid on   hesop_patient           (patid);
CREATE INDEX idx_patid on   linkage_eligibility     (patid);
CREATE INDEX idx_patid on   patient_2019_imd        (patid);

CREATE INDEX idx_patid_attendkey on   hesop_clinical (patid, attendkey);

CREATE INDEX idx_patid_attendkey on   hesop_appointment           (patid, attendkey);

CREATE INDEX idx_patid_attendkey on   hesop_operation           (patid, attendkey);
CREATE INDEX idx_patid_attendkey on   hesop_patient_pathway           (patid, attendkey);


CREATE INDEX idx_patid_attendkey on   hesop_clinical_apptdate (patid, attendkey);
