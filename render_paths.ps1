<#
.SYNOPSIS
Fill in local path roots for the requested scripts.
.EXAMPLE
.\render_paths.ps1 -Path oxcprd_002_sql_scripts
.EXAMPLE
.\render_paths.ps1 -Path aurum_bmi,aurum_smoking -Check
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Path,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot.TrimEnd('\', '/')
$roots = Get-Content -LiteralPath "$repoRoot/local/paths.json" -Raw |
    ConvertFrom-Json
$utf8 = [Text.UTF8Encoding]::new($false)

# Git picks up new scripts and respects .gitignore.
$files = @(git -C $repoRoot -c core.quotepath=false ls-files `
    --cached --others --exclude-standard)
if ($LASTEXITCODE -ne 0) { throw 'Cannot list repository files.' }
$files = @($files | Where-Object {
    $_ -match '\.(sql|ps1|r|md)$' -and $_ -ne 'render_paths.ps1'
})
$selected = foreach ($item in $Path) {
    $target = if ([IO.Path]::IsPathRooted($item)) { $item }
        else { Join-Path $repoRoot $item }
    $target = [IO.Path]::GetFullPath($target)
    if ($target -ne $repoRoot -and -not $target.StartsWith(
        "$repoRoot\", [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Choose a source folder or file inside this repository.'
    }
    $relative = $target.Substring($repoRoot.Length).
        TrimStart('\', '/').Replace('\', '/').TrimEnd('/')
    $matches = @($files | Where-Object {
        $relative -eq '' -or $_ -eq $relative -or
        $_.StartsWith($relative + '/', [StringComparison]::OrdinalIgnoreCase)
    })
    if ($matches.Count -eq 0) { throw "No source scripts found in: $item" }
    $matches
}
$selected = @($selected | Sort-Object -Unique)

# Resolve everything first; a missing root should leave the existing copies alone.
$prepared = foreach ($name in $selected) {
    $text = [IO.File]::ReadAllText((Join-Path $repoRoot $name))
    $extension = [IO.Path]::GetExtension($name).ToLowerInvariant()
    $expanded = [regex]::Replace($text, '\{\{([A-Z0-9_]+)\}\}', {
        param($match)
        $key = $match.Groups[1].Value
        $property = $roots.PSObject.Properties[$key]
        if (-not $property -or $property.Value -isnot [string] -or
            [string]::IsNullOrWhiteSpace($property.Value)) {
            throw "Set $key in local/paths.json before rendering."
        }
        $value = $property.Value.Replace('\', '/').TrimEnd('/')
        if ($value -match '[\r\n\x00]' -or $value.Contains('{{')) {
            throw "Invalid root value: $key"
        }
        $after = $match.Index + $match.Length
        if ($extension -eq '.ps1' -or
            ($after -lt $text.Length -and $text[$after] -eq '\')) {
            $value = $value.Replace('/', '\')
        }
        $lineStart = $text.LastIndexOf("`n", $match.Index) + 1
        $line = $text.Substring($lineStart, $match.Index - $lineStart).
            TrimStart()
        $comment = $line.StartsWith('#') -or $line.StartsWith('--')
        if (-not $comment) {
            $quote = if ($match.Index -gt 0) { $text[$match.Index - 1] }
                else { '' }
            if ($quote -ne "'" -and $quote -ne '"') {
                throw "Place {{$key}} at the start of a quoted path."
            }
            if ($extension -eq '.sql') {
                $value = $value.Replace('\', '\\').
                    Replace([string]$quote, ([string]$quote + $quote))
            } elseif ($extension -eq '.r') {
                $value = $value.Replace('\', '\\').
                    Replace([string]$quote, ('\' + $quote))
            } elseif ($quote -eq "'") {
                $value = $value.Replace("'", "''")
            } else {
                $value = $value.Replace('`', '``').Replace('$', '`$').
                    Replace('"', '`"')
            }
        }
        $value
    })
    [pscustomobject]@{ Name = $name; Text = $expanded }
}
$prepared = @($prepared)
if ($Check) {
    Write-Output "Validated $($prepared.Count) script(s); no files written."
    return
}

# These copies stay under local/ so Git leaves the expanded paths out.
foreach ($script in $prepared) {
    $destination = Join-Path "$repoRoot/local/rendered" $script.Name
    [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) |
        Out-Null
    [IO.File]::WriteAllText($destination, $script.Text, $utf8)
}
Write-Output "Rendered $($prepared.Count) script(s) under local/rendered/."
