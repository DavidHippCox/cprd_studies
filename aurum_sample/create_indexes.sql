-- Authored by David Hippisley-Cox
-- project: aurum_sample
-- analysis plan version: NA
use aurum_dev;

-- SET GLOBAL innodb_buffer_pool_size=(80 * 1024 * 1024 * 1024);

CREATE INDEX idx_patid ON consultation (patid);
CREATE INDEX idx_patid ON death_patient (patid);
CREATE INDEX idx_patid ON drugissue (patid);
CREATE INDEX idx_prodcodeid_issuedate ON drugissue (prodcodeid, issuedate);

CREATE INDEX idx_patid ON ethnicity_record (patid);
CREATE INDEX idx_patid ON hesae_attendance (patid);
CREATE INDEX idx_patid ON hesae_diagnosis (patid);
CREATE INDEX idx_patid ON hesae_hrg (patid);
CREATE INDEX idx_patid ON hesae_investigation (patid);
CREATE INDEX idx_patid ON hesae_pathway (patid);
CREATE INDEX idx_patid ON hesae_patient (patid);
CREATE INDEX idx_patid ON hesae_treatment (patid);
CREATE INDEX idx_patid_attendkey ON hesop_appointment (patid, attendkey);

CREATE INDEX idx_patid_attendkey ON hesop_clinical (patid, attendkey);
CREATE INDEX idx_patid ON hesop_clinical_apptdate (patid);
CREATE INDEX idx_icd10_date on   hesop_clinical_apptdate          (icd, apptdate); 

CREATE INDEX idx_patid_attendkey ON hesop_operation (patid, attendkey);
CREATE INDEX idx_patid ON hesop_patient (patid);
CREATE INDEX idx_patid_attendkey ON hesop_patient_pathway (patid, attendkey);

CREATE INDEX idx_patid ON hes_ccare (patid);

CREATE INDEX idx_patid ON hes_diagnosis_epi (patid);
CREATE INDEX idx_icd10_date on   hes_diagnosis_epi       (ICD, epistart);

CREATE INDEX idx_patid ON hes_diagnosis_hosp (patid);
CREATE INDEX idx_icd10_date on   hes_diagnosis_hosp      (ICD, admidate);


CREATE INDEX idx_patid ON hes_episodes (patid);
CREATE INDEX idx_patid ON hes_hospital (patid);
CREATE INDEX idx_patid ON hes_hrg (patid);
CREATE INDEX idx_patid ON hes_maternity (patid);
CREATE INDEX idx_patid ON hes_patient (patid);

CREATE INDEX idx_patid ON hes_primary_diag_hosp (patid);
CREATE INDEX idx_icd10_date on   hes_primary_diag_hosp   (ICD_PRIMARY, admidate);


CREATE INDEX idx_patid ON hes_procedures_epi (patid);
CREATE INDEX idx_patid ON linkage_eligibility (patid);

CREATE INDEX idx_patid ON observation (patid);
CREATE INDEX idx_medcodeid_obsdate ON observation (medcodeid, obsdate);


CREATE INDEX idx_patid ON patient (patid);
CREATE INDEX idx_patid ON patient_2019_imd (patid);


CREATE INDEX idx_patid ON practice (pracid);
CREATE INDEX idx_patid ON practice_imd (pracid);


CREATE INDEX idx_patid ON problem (patid);
CREATE INDEX idx_patid ON referral (patid);



SELECT
         table_name,
         data_length,
         index_length,
         ROUND(data_length / 16384) AS data_pages,
         ROUND(index_length / 16384) AS index_pages,
         ROUND((data_length + index_length) / 16384) AS total_pages
     FROM information_schema.tables
     WHERE table_schema = 'aurum_dev'
       AND table_name = 'drugissue';