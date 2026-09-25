<#
.SYNOPSIS
  Builds Zen's two release artifacts: the Windows installer and the signed APK.

.DESCRIPTION
  ZEN_SPEC.md §11.9. This is how a V1 release is cut. There is deliberately no
  CI release job -- see §11.10 and V2-1 in V2_BACKLOG.md.

  Both artifacts land in dist\ at the repository root.

  The version comes from `version:` in packages/zen_app/pubspec.yaml and is
  passed to every consumer, so the installer, the APK and the About row cannot
  disagree about which release this is.

.PARAMETER WindowsOnly
  Build and package the Windows installer only.

.PARAMETER AndroidOnly
  Build the signed APK only.

.PARAMETER FlutterBin
  The Flutter SDK's bin directory, if it is not on PATH and not at the default
  location. Mirrors tools\verify.ps1.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\package.ps1
#>
[CmdletBinding()]
param(
  [switch]$WindowsOnly,
  [switch]$AndroidOnly,
  [string]$FlutterBin = 'C:\src\flutter\bin'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir   = Join-Path $repoRoot 'packages\zen_app'
$distDir  = Join-Path $repoRoot 'dist'

function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host "`nFAILED: $text" -ForegroundColor Red; exit 1 }

# --- Flutter on PATH (same treatment as tools\verify.ps1) ---------------------
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  if (Test-Path $FlutterBin) {
    $env:PATH = "$FlutterBin;$env:PATH"
  } else {
    Fail "Flutter is not on PATH and '$FlutterBin' does not exist. Pass -FlutterBin."
  }
}

# --- The one version number (§11.9) -------------------------------------------
Step 'version'
$pubspec = Join-Path $appDir 'pubspec.yaml'
$versionLine = Select-String -Path $pubspec -Pattern '^version:\s*(\S+)\s*$' | Select-Object -First 1
if (-not $versionLine) { Fail "No 'version:' line in $pubspec." }
$fullVersion = $versionLine.Matches[0].Groups[1].Value      # e.g. 1.0.0+1
$parts       = $fullVersion -split '\+'
$appVersion  = $parts[0]                                    # 1.0.0
$buildNumber = if ($parts.Count -gt 1) { $parts[1] } else { '1' }
if ($appVersion -notmatch '^\d+\.\d+\.\d+$') {
  Fail "Version '$appVersion' is not x.y.z. Inno Setup's VersionInfoVersion requires that shape."
}
Write-Host "  version $appVersion, build $buildNumber (APK versionCode $buildNumber)"
Write-Host "  SPEC 11.9: versionCode must never decrease. Confirm this is above the last release." -ForegroundColor Yellow

New-Item -ItemType Directory -Force -Path $distDir | Out-Null

# ==============================================================================
# Windows
# ==============================================================================
if (-not $AndroidOnly) {

  # `flutter build windows` needs symlink support: an elevated terminal, or
  # Developer Mode. Developer Mode is off on the owner's machine by standing
  # choice, so the build is run from an elevated PowerShell (D-M4-16). Without
  # either, Flutter stops at "Building with plugins requires symlink support",
  # which reads like a defect in this project and is not one. Say so before the
  # build rather than leaving it to be rediscovered after.
  $elevated = ([Security.Principal.WindowsPrincipal] `
      [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $elevated) {
    Write-Host @"

  This shell is not elevated.

  'flutter build windows' needs symlink support, which comes from either
  Developer Mode or an elevated terminal. Developer Mode is off on this machine
  by choice, so Windows builds are run from an elevated PowerShell
  (DECISIONS.md, D-M4-16). If the build below stops at "Building with plugins
  requires symlink support", that is the cause, and it is not a defect in this
  project.

"@ -ForegroundColor Yellow
  }

  # A running Zen holds a lock on zen_app.exe, and the linker cannot overwrite
  # it. MSVC reports that as "LINK : fatal error LNK1104: cannot open file
  # ...\zen_app.exe", which names the file but not the cause, and reads like a
  # corrupt build directory. It is not: it is the application being open. This
  # cost a diagnosis on the first real release build (D-M8-10).
  #
  # Deliberately not killed automatically -- a release build is no reason to
  # terminate an app that could be mid-sync. Same reasoning as CloseApplications
  # in zen.iss.
  $running = Get-Process zen_app -ErrorAction SilentlyContinue
  if ($running) {
    $paths = ($running | ForEach-Object { $_.Path }) -join "`n    "
    Fail @"
Zen is running, so the linker cannot overwrite zen_app.exe.

    $paths

Close Zen and run this again. (Left unhandled, this surfaces as
'LINK : fatal error LNK1104: cannot open file ...\zen_app.exe', which names the
file but not the reason.)
"@
  }

  Step 'flutter build windows --release'
  Push-Location $appDir
  try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { Fail 'flutter build windows failed.' }
  } finally { Pop-Location }

  $bundleDir = Join-Path $appDir 'build\windows\x64\runner\Release'
  if (-not (Test-Path (Join-Path $bundleDir 'zen_app.exe'))) {
    Fail "No zen_app.exe in $bundleDir."
  }

  # --- The Visual C++ runtime (§11.9) -----------------------------------------
  # Taken from the toolchain's Redist directory, which is what Microsoft
  # licenses for app-local deployment -- deliberately not from System32, which
  # is this machine's own copy and is not redistributable.
  Step 'locating the Visual C++ redistributable'
  $redistRoots = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022",
    "$env:ProgramFiles\Microsoft Visual Studio\2022"
  ) | Where-Object { Test-Path $_ }

  $redistDir = $null
  foreach ($root in $redistRoots) {
    $candidate = Get-ChildItem -Path $root -Recurse -Directory -Filter 'Microsoft.VC*.CRT' `
                   -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\Redist\\MSVC\\' -and $_.FullName -match '\\x64\\' } |
      Where-Object { Test-Path (Join-Path $_.FullName 'vcruntime140_1.dll') } |
      Sort-Object FullName -Descending | Select-Object -First 1
    if ($candidate) { $redistDir = $candidate.FullName; break }
  }
  if (-not $redistDir) {
    Fail @"
Could not find the Visual C++ redistributable DLLs.

Expected somewhere under:
  <Visual Studio 2022>\VC\Redist\MSVC\<version>\x64\Microsoft.VC143.CRT\

They ship with the 'Desktop development with C++' workload. SPEC 11.9 requires
the installer to carry msvcp140.dll, vcruntime140.dll and vcruntime140_1.dll
app-local, because the Flutter bundle does not -- and a clean machine without
them fails to launch with a missing-DLL dialog that names nothing useful.
"@
  }
  Write-Host "  $redistDir"

  # --- Inno Setup ---------------------------------------------------------------
  Step 'Inno Setup'
  $iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
  if (-not $iscc) {
    $iscc = @(
      "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
      "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
      "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  }
  if (-not $iscc) {
    Fail "Inno Setup 6 was not found. Install it with:  winget install -e --id JRSoftware.InnoSetup"
  }
  Write-Host "  $iscc"

  $iss = Join-Path $repoRoot 'packaging\windows\zen.iss'
  & $iscc `
    "/DAppVersion=$appVersion" `
    "/DSourceDir=$bundleDir" `
    "/DRedistDir=$redistDir" `
    "/DOutputDir=$distDir" `
    $iss
  if ($LASTEXITCODE -ne 0) { Fail 'ISCC failed.' }

  $installer = Join-Path $distDir "Zen-$appVersion-setup.exe"
  if (-not (Test-Path $installer)) { Fail "ISCC reported success but $installer is missing." }
  $mb = [math]::Round((Get-Item $installer).Length / 1MB, 1)
  Write-Host "  $installer ($mb MB)" -ForegroundColor Green
}

# ==============================================================================
# Android
# ==============================================================================
if (-not $WindowsOnly) {

  # §11.9. No fallback to debug keys. The Gradle build fails on its own if this
  # is missing (D-M8-3); checking here too turns a Gradle stack trace into a
  # sentence, and does it before a multi-minute build rather than after.
  $keyProps = Join-Path $appDir 'android\key.properties'
  if (-not (Test-Path $keyProps)) {
    Fail @"
packages\zen_app\android\key.properties does not exist, so there is no signing
keystore (SPEC 11.9).

Falling back to the debug keystore is deliberately not done: a debug-signed APK
installs cleanly on this machine's own device and can then never be upgraded by
a properly signed one without an uninstall, which destroys the local database.

MANUAL_VERIFICATION.md, section "M8 -- the keystore", has the keytool command
and the backup step. Use -WindowsOnly to skip Android for now.
"@
  }

  # §11.9: a single universal APK, never --split-per-abi. Splitting adds
  # 1000 x ABI index to versionCode, producing a number a later universal build
  # cannot get above.
  Step 'flutter build apk --release'
  Push-Location $appDir
  try {
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { Fail 'flutter build apk failed.' }
  } finally { Pop-Location }

  $builtApk = Join-Path $appDir 'build\app\outputs\flutter-apk\app-release.apk'
  if (-not (Test-Path $builtApk)) { Fail "No APK at $builtApk." }

  $apk = Join-Path $distDir "Zen-$appVersion+$buildNumber.apk"
  Copy-Item $builtApk $apk -Force
  $mb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
  Write-Host "  $apk ($mb MB)" -ForegroundColor Green

  # Prove what it was signed with rather than assuming. A debug-signed APK
  # carries CN=Android Debug; anything else is the real keystore.
  Step 'signature'
  $apksigner = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Filter 'apksigner.bat' `
                 -Recurse -ErrorAction SilentlyContinue |
               Sort-Object FullName -Descending | Select-Object -First 1
  if ($apksigner) {
    $out = & $apksigner.FullName verify --print-certs $apk 2>&1 | Out-String
    Write-Host $out
    if ($out -match 'CN=Android Debug') {
      Fail 'This APK is signed with the DEBUG key. Do not distribute it. SPEC 11.9.'
    }
  } else {
    Write-Host '  apksigner not found; signature not checked. Verify by hand.' -ForegroundColor Yellow
  }
}

Write-Host "`nDONE. Artifacts in $distDir" -ForegroundColor Green
Write-Host "Next: MANUAL_VERIFICATION.md, section 'M8 -- packaging'." -ForegroundColor Green
