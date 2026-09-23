# Runs everything CI runs (§11.10), in CI's order, on Windows.
#
# .github/workflows/ci.yaml is the authority; this is the same sequence for a
# local machine, so a green run here means a green run there. Keep the two in
# step when either changes.
#
#   .\tools\verify.ps1              full sequence
#   .\tools\verify.ps1 -SkipFlutter domain and sync only (a few seconds)

[CmdletBinding()]
param(
    # Skip the two Flutter packages. `dart test` on zen_domain is the fast
    # inner loop; `flutter test` costs a few seconds of startup.
    [switch]$SkipFlutter,

    # Where the Flutter SDK lives, if it is not already on PATH.
    [string]$FlutterBin = 'C:\src\flutter\bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Test-Path $FlutterBin) {
        $env:PATH = "$FlutterBin;$env:PATH"
    } else {
        throw "Flutter is not on PATH and $FlutterBin does not exist. Install Flutter 3.47.5 (see .fvmrc) or pass -FlutterBin."
    }
}

$failures = [System.Collections.Generic.List[string]]::new()

function Invoke-Step {
    param([string]$Name, [scriptblock]$Body)

    Write-Host ''
    Write-Host "== $Name" -ForegroundColor Cyan
    & $Body
    if ($LASTEXITCODE -ne 0) {
        $failures.Add($Name)
        Write-Host "   FAILED" -ForegroundColor Red
    }
}

$dartPackages = @('zen_domain', 'zen_sync')
$flutterPackages = @('zen_data', 'zen_app')
$allPackages = $dartPackages + $flutterPackages
if ($SkipFlutter) { $allPackages = $dartPackages }

Push-Location $repoRoot
try {
    & flutter --version | Select-Object -First 1

    # §11.10 step 4.
    Invoke-Step 'dart format' { & dart format --output=none --set-exit-if-changed . }

    # §11.11: the DateTime.now() ban outside zen_app.
    Invoke-Step 'DateTime.now() guard' {
        & 'C:\Program Files\Git\bin\bash.exe' 'tools/check_no_datetime_now.sh'
    }

    # §11.10 step 1: warnings as errors.
    foreach ($package in $allPackages) {
        Invoke-Step "analyze $package" {
            Push-Location (Join-Path 'packages' $package)
            try { & dart analyze --fatal-infos --fatal-warnings } finally { Pop-Location }
        }
    }

    # §11.10 step 2.
    foreach ($package in $dartPackages) {
        Invoke-Step "dart test $package" {
            Push-Location (Join-Path 'packages' $package)
            try { & dart test } finally { Pop-Location }
        }
    }

    # §11.10 step 3.
    if (-not $SkipFlutter) {
        foreach ($package in $flutterPackages) {
            Invoke-Step "flutter test $package" {
                Push-Location (Join-Path 'packages' $package)
                try { & flutter test } finally { Pop-Location }
            }
        }
    }
} finally {
    Pop-Location
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'ALL GREEN' -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILED: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}
