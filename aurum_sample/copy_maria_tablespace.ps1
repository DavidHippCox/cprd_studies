$SourceDb = "{{DATA_ROOT}}\mariadb-12.3.2-winx64\mariadb_backup\data\aurum_dev"

 $TargetDb = "{{PROJECT_ROOT}}\cprd_sample\mariadb-12.3.2-winx64\data\aurum_dev"

 $Tables = @(
     "consultation",
     "death_patient",
     "drugissue",
     "ethnicity_record",
     "hesae_attendance",
     "hesae_diagnosis",
     "hesae_hrg",
     "hesae_investigation",
     "hesae_pathway",
     "hesae_patient",
     "hesae_treatment",
     "hesop_appointment",
     "hesop_clinical",
     "hesop_clinical_apptdate",
     "hesop_operation",
     "hesop_patient",
     "hesop_patient_pathway",
     "hes_ccare",
     "hes_diagnosis_epi",
     "hes_diagnosis_hosp",
     "hes_episodes",
     "hes_hospital",
     "hes_hrg",
     "hes_maternity",
     "hes_patient",
     "hes_primary_diag_hosp",
     "hes_procedures_epi",
     "linkage_eligibility",
     "observation",
     "patient",
     "patient_2019_imd",
     "practice",
     "practice_imd",
     "problem",
     "referral",
     "staff"
 )

 $Files = @()

 foreach ($Table in $Tables) {

     $Ibd = Join-Path $SourceDb "$Table.ibd"
     $Cfg = Join-Path $SourceDb "$Table.cfg"

     if (-not (Test-Path -LiteralPath $Ibd)) {
         throw "Missing source file: $Ibd"
     }

     if (-not (Test-Path -LiteralPath $Cfg)) {
         throw "Missing source file: $Cfg"
     }

     $Files += "$Table.ibd"
     $Files += "$Table.cfg"
 }

 Write-Host "Copying tables directly to target..."

 & robocopy.exe `
     $SourceDb `
     $TargetDb `
     $Files `
     /J `
     /R:2 `
     /W:5 `
     /COPY:DAT `
     /NP

 $Rc = $LASTEXITCODE

 if ($Rc -ge 8) {
     throw "Robocopy failed with exit code $Rc"
 }

 Write-Host "Copy completed successfully. Robocopy exit code: $Rc"