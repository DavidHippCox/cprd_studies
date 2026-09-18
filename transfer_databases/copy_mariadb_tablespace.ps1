param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,

    [Parameter(Mandatory = $true)]
    [string]$MariaDbVersion,

    [Parameter(Mandatory = $true)]
    [string]$Database,

    [Parameter(Mandatory = $true)]
    [string[]]$Tables,

    [Parameter(Mandatory = $true)]
    [string]$TargetFolder,

    [string]$SourceData = '',
    [string]$TargetData = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
    throw 'TargetFolder cannot be empty'
}

if ([string]::IsNullOrWhiteSpace($SourceData)) {
    $SourceData = Join-Path $BasePath "data\$MariaDbVersion\data\$Database"
}

if ([string]::IsNullOrWhiteSpace($TargetData)) {
    $TargetData = Join-Path $BasePath "$TargetFolder\$MariaDbVersion\data\$Database"
}

if (-not (Test-Path -LiteralPath $SourceData)) {
    throw "Source data directory does not exist: $SourceData"
}

if (-not (Test-Path -LiteralPath $TargetData)) {
    throw "Target data directory does not exist: $TargetData"
}

$Files = [System.Collections.Generic.List[string]]::new()

foreach ($Table in $Tables) {
    $Ibd = Join-Path $SourceData "$Table.ibd"
    $Cfg = Join-Path $SourceData "$Table.cfg"

    if (-not (Test-Path -LiteralPath $Ibd)) {
        throw "Missing source file: $Ibd"
    }

    if (-not (Test-Path -LiteralPath $Cfg)) {
        throw "Missing source file: $Cfg"
    }

    [void]$Files.Add("$Table.ibd")
    [void]$Files.Add("$Table.cfg")
}

Write-Host "Source: $SourceData"
Write-Host "Target: $TargetData"
Write-Host "Tables: $($Tables.Count)"
Write-Host "Copying tablespace files..."

& robocopy.exe `
    $SourceData `
    $TargetData `
    $Files `
    /J `
    /R:2 `
    /W:5 `
    /COPY:DAT `
    /NP

$Rc = $LASTEXITCODE

# Robocopy uses 0-7 for success/non-failure statuses and 8+ for failure.
if ($Rc -ge 8) {
    throw "Robocopy failed with exit code $Rc"
}

Write-Host "Copy completed successfully. Robocopy exit code: $Rc"

