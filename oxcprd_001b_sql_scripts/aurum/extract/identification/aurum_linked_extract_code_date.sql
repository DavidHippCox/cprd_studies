-- Authored by David Hippisley-Cox
-- project: oxcprd_001b
-- Implements v1 Analysis Plan  
-- dementia hes --
CALL extract_linked_by_code_to_table (
  'hes_diagnosis_epi',
  'aurum_oxcprd_001b',
  'dementia_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,epistart,ICD',
  'dementia_hes_diagnosis_epi',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hes_diagnosis_hosp',
  'aurum_oxcprd_001b',
  'dementia_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,admidate,ICD',
  'dementia_hes_diagnosis_hosp',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hes_primary_diag_hosp',
  'aurum_oxcprd_001b',
  'dementia_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,admidate,ICD_PRIMARY',
  'dementia_hes_primary_diag_hosp',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hesop_clinical_apptdate',
  'aurum_oxcprd_001b',
  'dementia_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,apptdate,icd',
  'dementia_hesop_clinical_apptdate',
  TRUE
);

--------------------------------------
--Alcohol
--------------------------------------
CALL extract_linked_by_code_to_table (
  'hes_diagnosis_epi',
  'aurum_oxcprd_001b',
  'alcohol_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,epistart,ICD',
  'alcohol_hes_diagnosis_epi',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hes_diagnosis_hosp',
  'aurum_oxcprd_001b',
  'alcohol_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,admidate,ICD',
  'alcohol_hes_diagnosis_hosp',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hes_primary_diag_hosp',
  'aurum_oxcprd_001b',
  'alcohol_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,admidate,ICD_PRIMARY',
  'alcohol_hes_primary_diag_hosp',
  TRUE
);

CALL extract_linked_by_code_to_table (
  'hesop_clinical_apptdate',
  'aurum_oxcprd_001b',
  'alcohol_codes_icd10',
  '1998-01-02',
  '2024-12-31',
  'patid,apptdate,icd',
  'alcohol_hesop_clinical_apptdate',
  TRUE
);
