$BasePath = '{{PROJECT_ROOT}}'

$Tables = @(
    'consultation',
    'death_patient',
    'drugissue',
    'ethnicity_record',
    'hesae_attendance',
    'hesae_diagnosis',
    'hesae_hrg',
    'hesae_investigation',
    'hesae_pathway',
    'hesae_patient',
    'hesae_treatment',
    'hesop_appointment',
    'hesop_clinical',
    'hesop_clinical_apptdate',
    'hesop_operation',
    'hesop_patient',
    'hesop_patient_pathway',
    'hes_ccare',
    'hes_diagnosis_epi',
    'hes_diagnosis_hosp',
    'hes_episodes',
    'hes_hospital',
    'hes_hrg',
    'hes_maternity',
    'hes_patient',
    'hes_primary_diag_hosp',
    'hes_procedures_epi',
    'linkage_eligibility',
    'observation',
    'patient',
    'patient_2019_imd',
    'practice',
    'practice_imd',
    'problem',
    'referral',
    'staff'
)

.\copy_mariadb_tablespaces.ps1 `
    -BasePath $BasePath `
    -MariaDbVersion 'mariadb-12.3.2-winx64' `
    -TargetFolder 'oxcprd_003' `
    -Database 'aurum_dev' `
    -Tables $Tables