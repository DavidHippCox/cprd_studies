CREATE INDEX IF NOT EXISTS idx_icd_epistart_patid
    ON hes_diagnosis_epi (ICD, epistart, patid);

CREATE INDEX IF NOT EXISTS idx_icd_adimate_patid
    ON hes_diagnosis_hosp (ICD, admidate, patid);

CREATE INDEX IF NOT EXISTS idx_icd_primary_admidate_patid
    ON hes_primary_diag_hosp (ICD_PRIMARY, admidate, patid);




