-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
USE aurum_oxcprd_001b;

-- hes_diagnosis_epi
CREATE INDEX idx_patid ON hes_diagnosis_epi (patid);

CREATE INDEX idx_icd10_date ON hes_diagnosis_epi (icd, epistart);

-- hes_diagnosis_hosp
CREATE INDEX idx_patid ON hes_diagnosis_hosp (patid);

CREATE INDEX idx_icd10_date ON hes_diagnosis_hosp (icd, admidate);

-- hes_primary_diag_hosp
CREATE INDEX idx_patid ON hes_primary_diag_hosp (patid);

CREATE INDEX idx_icd10_date ON hes_primary_diag_hosp (ICD_PRIMARY, admidate);

-- hesop_clinical_apptdate
CREATE INDEX idx_patid ON hesop_clinical_apptdate (patid);

CREATE INDEX idx_icd10_date ON hesop_clinical_apptdate (icd, apptdate);

-- other linked tables
CREATE INDEX idx_patid ON patient_2019_imd (patid);

CREATE INDEX idx_patid ON death_patient (patid);

CREATE INDEX idx_patid ON linkage_eligibility (patid);

CREATE INDEX idx_patid ON ethnicity_record (patid);

CREATE INDEX idx_patid ON hes_patient (patid);

CREATE INDEX idx_patid ON practice_imd (pracid);
