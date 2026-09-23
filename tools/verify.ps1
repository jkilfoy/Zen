# Runs everything CI runs (§11.10), in CI's order, on Windows.
#
# .github/workflows/ci.yaml is the authority; this is the same sequence for a
# local machine, so a green run here means a green run there. Keep the two in
# step when either changes.
#
#   .\tools\verify.ps1              full sequence
#   .\tools\verify.ps1 -SkipFlutter domain and sync only (a few seconds)
#   .\tools\verify.ps1 -Clean       delete .dart_tool first and re-resolve
#
# The first step is `pub get`, exactly as in CI. It is not optional: each
# package's .dart_tool/package_config.json is the package resolution, it is
# gitignored because it holds absolute machine paths, and `dart analyze` does
# NOT regenerate it. Without it every `package:` import reports as
# "Target of URI doesn't exist" and the run looks like the code is broken.

[CmdletBinding()]
param(
    # Skip the two Flutter packages. `dart test` on zen_domain is the fast
    # inner loop; `flutter test` costs a few seconds of startup.
    [switch]$SkipFlutter,

    # Delete each package's .dart_tool before resolving. Use when resolution
    # looks wrong rather than deleting things by hand.
    [switch]$Clean,

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

# The Drift output D-M0-12 commits on purpose. Kept beside the packages list
# so the two are read together.
$generatedPaths = @(
    'packages/zen_data/lib/src/database.g.dart',
    'packages/zen_data/lib/src/schema_versions.dart',
    'packages/zen_data/drift_schemas',
    'packages/zen_data/test/generated_migrations'
)

$dartPackages = @('zen_domain', 'zen_sync')
$flutterPackages = @('zen_data', 'zen_app')
$allPackages = $dartPackages + $flutterPackages
if ($SkipFlutter) { $allPackages = $dartPackages }

Push-Location $repoRoot
try {
    & flutter --version | Select-Object -First 1
    Write-Host "dart: $((Get-Command dart).Source)"

    if ($Clean) {
        foreach ($package in $allPackages) {
            $dartTool = Join-Path (Join-Path 'packages' $package) '.dart_tool'
            if (Test-Path $dartTool) {
                Remove-Item $dartTool -Recurse -Force
                Write-Host "removed $dartTool"
            }
        }
    }

    # Resolve dependencies first, as ci.yaml does. See the header comment.
    foreach ($package in $allPackages) {
        Invoke-Step "pub get $package" {
            Push-Location (Join-Path 'packages' $package)
            try { & flutter pub get | Out-Null } finally { Pop-Location }
        }
    }

    # M3. Drift generates `database.g.dart` and the schema-migration harness,
    # and D-M0-12 commits that output on purpose. "Committed but not
    # regenerated" is therefore a real failure mode, and it fails late and
    # confusingly if nothing looks for it — so regenerate, then require the
    # working tree to be unchanged.
    Invoke-Step 'build_runner zen_data' {
        Push-Location (Join-Path 'packages' 'zen_data')
        try { & dart run build_runner build } finally { Pop-Location }
    }
    # Scoped to the generated paths only, so that work in progress elsewhere in
    # the package does not read as stale generated output. `git status` rather
    # than `git diff`, so that generated output which was never added at all is
    # caught too.
    Invoke-Step 'generated output is current' {
        $dirty = & git status --porcelain -- $generatedPaths
        if ($dirty) {
            $dirty | ForEach-Object { Write-Host "   $_" }
            Write-Host '   Generated Drift output is stale or unstaged. Commit the'
            Write-Host '   result of `dart run build_runner build`.' -ForegroundColor Yellow
            $global:LASTEXITCODE = 1
        } else {
            $global:LASTEXITCODE = 0
        }
    }

    # §11.10 step 4. Runs after the build so that generated output is checked
    # too — the analyzer excludes it, the formatter cannot.
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
