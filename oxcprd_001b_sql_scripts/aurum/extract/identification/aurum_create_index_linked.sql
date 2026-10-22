-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
USE aurum_oxcprd_001b;

-- alcohol_hes_diagnosis_epi
CREATE INDEX idx_patid ON alcohol_hes_diagnosis_epi (patid);

CREATE INDEX idx_icd10_date ON alcohol_hes_diagnosis_epi (icd, epistart);

-- alcohol_hes_diagnosis_hosp
CREATE INDEX idx_patid ON alcohol_hes_diagnosis_hosp (patid);

CREATE INDEX idx_icd10_date ON alcohol_hes_diagnosis_hosp (icd, admidate);

-- alcohol_hes_primary_diag_hosp
CREATE INDEX idx_patid ON alcohol_hes_primary_diag_hosp (patid);

CREATE INDEX idx_icd10_date ON alcohol_hes_primary_diag_hosp (ICD_PRIMARY, admidate);

-- alcohol_hesop_clinical_apptdate
CREATE INDEX idx_patid ON alcohol_hesop_clinical_apptdate (patid);

CREATE INDEX idx_icd10_date ON alcohol_hesop_clinical_apptdate (icd, apptdate);

-- dementia_hes_diagnosis_epi
CREATE INDEX idx_patid ON dementia_hes_diagnosis_epi (patid);

CREATE INDEX idx_icd10_date ON dementia_hes_diagnosis_epi (icd, epistart);

-- dementia_hes_diagnosis_hosp
CREATE INDEX idx_patid ON dementia_hes_diagnosis_hosp (patid);

CREATE INDEX idx_icd10_date ON dementia_hes_diagnosis_hosp (icd, admidate);

-- dementia_hes_primary_diag_hosp
CREATE INDEX idx_patid ON dementia_hes_primary_diag_hosp (patid);

CREATE INDEX idx_icd10_date ON dementia_hes_primary_diag_hosp (ICD_PRIMARY, admidate);

-- dementia_hesop_clinical_apptdate
CREATE INDEX idx_patid ON dementia_hesop_clinical_apptdate (patid);

CREATE INDEX idx_icd10_date ON dementia_hesop_clinical_apptdate (icd, apptdate);
