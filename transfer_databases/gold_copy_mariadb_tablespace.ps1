# Authored by David Hippisley-Cox
# project: transfer_databases
# analysis plan version: NA
$SourceDb = "{{DATA_ROOT}}\mariadb-12.3.2-winx64\data\gold"

$TargetDb = "{{DATA_ROOT}}\mariadb-12.3.2-winx64\mariadb_backup\data\gold"

$Tables = @(
  'additional',
  'clinical_001',
  'clinical_002',
  'clinical_003',
  'consultation_001',
  'consultation_002',
  'consultation_003',
  'consultation_004',
  'gold_import_progress',
  'immunisation',
  'patient',
  'practice',
  'referral',
  'staff',
  'test_001',
  'test_002',
  'test_003',
  'therapy_001',
  'therapy_002',
  'therapy_003'
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