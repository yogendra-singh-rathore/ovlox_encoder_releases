<#
.SYNOPSIS
    Prepares a new Ovlox Encoder release: verifies the build, hashes it, and rewrites latest.json.

.DESCRIPTION
    Run this AFTER building the installer in the private ovlox_encoder repo. It does everything
    that must not be done by hand -- getting the version, hash and size right -- then prints the
    remaining manual steps (creating the GitHub Release and uploading the .exe).

    latest.json is what installed copies poll to discover updates, so a wrong hash here means
    every client refuses the update. That is why this is scripted.

.EXAMPLE
    .\tools\new-release.ps1 -Version 2.3.0 -Notes "Fixes card write timeout","Adds beep on success"

.EXAMPLE
    .\tools\new-release.ps1 -Version 2.3.1 -Notes "Critical fix" -Mandatory
#>
[CmdletBinding()]
param(
    # Version being released, e.g. 2.3.0. Must match the built installer's file version.
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    # Release notes, one string per bullet. Shown in the update prompt AND on the website.
    [string[]]$Notes = @(),

    # Set for a release clients must not postpone (security fix, breaking HMS change).
    [switch]$Mandatory,

    # Clients older than this are forced to update. Defaults to keeping the existing value.
    [string]$MinVersion,

    # Folder holding the built installer. Defaults to the sibling private repo.
    [string]$BuildDir = "$PSScriptRoot\..\..\v2_exe\installer_output",

    # Private signing key (ECDSA P-256 PEM). Kept OUTSIDE the repos, never committed. Encoder 2.4.2+
    # refuses any manifest whose detached signature doesn't verify against its embedded public key.
    [string]$KeyPath = "$env:USERPROFILE\.ovlox\encoder-signing-key.pem"
)

$ErrorActionPreference = 'Stop'
$repoRoot     = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $repoRoot 'latest.json'
$installer    = Join-Path $BuildDir "OvloxEncoderService-Setup-$Version.exe"

Write-Host ""
Write-Host "Preparing release v$Version" -ForegroundColor Cyan
Write-Host ("-" * 60)

# --- 1. The installer must exist -------------------------------------------------------------
if (-not (Test-Path $installer)) {
    Write-Host "ERROR: installer not found:" -ForegroundColor Red
    Write-Host "  $installer"
    Write-Host ""
    Write-Host "Build it first, in the private ovlox_encoder repo:" -ForegroundColor Yellow
    Write-Host '  dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o publish'
    Write-Host '  & "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer.iss'
    exit 1
}

# --- 2. The build must actually BE this version ----------------------------------------------
# Guards the classic mistake: bumping installer.iss but not the .csproj, so a "2.3.0" installer
# ships a 2.2.0 exe. Clients compare assembly version, so they would re-prompt forever.
$fileVersion = (Get-Item $installer).VersionInfo.FileVersion
if ($fileVersion) {
    $normalised = ($fileVersion -replace '\s', '')
    if (-not $normalised.StartsWith($Version)) {
        Write-Host "ERROR: version mismatch." -ForegroundColor Red
        Write-Host "  Installer file version : $normalised"
        Write-Host "  Releasing as           : $Version"
        Write-Host ""
        Write-Host "Bump BOTH of these in the ovlox_encoder repo, then rebuild:" -ForegroundColor Yellow
        Write-Host "  OvloxEncoderService.csproj  -> <AssemblyVersion>/<FileVersion>/<Version>"
        Write-Host "  installer.iss               -> AppVersion / OutputBaseFilename"
        exit 1
    }
}

# --- 3. Hash + size ---------------------------------------------------------------------------
Write-Host "Hashing $([System.IO.Path]::GetFileName($installer)) ..." -NoNewline
$hash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $installer).Length
Write-Host " done"
Write-Host "  SHA-256 : $hash"
Write-Host "  Size    : $([math]::Round($size / 1MB, 1)) MB"

# --- 4. Carry forward anything not being changed ----------------------------------------------
$existingMin = '0.0.0'
if (Test-Path $manifestPath) {
    $prev = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if ($prev.minVersion) { $existingMin = $prev.minVersion }
    Write-Host "  Previous: v$($prev.version)"
}
if (-not $MinVersion) { $MinVersion = $existingMin }
if ($Notes.Count -eq 0) { $Notes = @("Maintenance and reliability improvements.") }

# --- 5. Write the manifest --------------------------------------------------------------------
$manifest = [ordered]@{
    version     = $Version
    releaseDate = (Get-Date -Format 'yyyy-MM-dd')
    url         = "https://github.com/yogendra-singh-rathore/ovlox_encoder_releases/releases/download/v$Version/OvloxEncoderService-Setup-$Version.exe"
    sha256      = $hash
    sizeBytes   = $size
    mandatory   = [bool]$Mandatory
    minVersion  = $MinVersion
    notes       = $Notes
}
# Write UTF-8 WITHOUT a BOM. Set-Content -Encoding utf8 on Windows PowerShell 5.1 always emits a
# BOM, and .NET's JsonSerializer.Deserialize(string) throws "'' is an invalid start of a value" on
# one -- i.e. a BOM here silently breaks the update check in every installed client.
$json = $manifest | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText($manifestPath, $json, (New-Object System.Text.UTF8Encoding($false)))

# Prove it parses and is BOM-free, rather than trusting that it is.
$bytes = [System.IO.File]::ReadAllBytes($manifestPath)
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "ERROR: latest.json was written with a BOM - clients would fail to parse it." -ForegroundColor Red
    exit 1
}
try { $null = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json }
catch {
    Write-Host "ERROR: latest.json is not valid JSON: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Updated latest.json (UTF-8, no BOM, parses OK)" -ForegroundColor Green

# --- 5b. SIGN the manifest. Clients 2.4.2+ FAIL CLOSED on a missing/invalid signature, so this is
#         mandatory on every release. Produces latest.json.sig (must be pushed WITH latest.json). ---
$signTool = Join-Path $PSScriptRoot '..\..\v2_exe\tools\manifest-sign'
if (-not (Test-Path $KeyPath)) {
    Write-Host "ERROR: signing key not found at $KeyPath" -ForegroundColor Red
    Write-Host "  Generate it once (then embed the printed public key in UpdateChecker.ManifestPublicKeyB64 and rebuild):" -ForegroundColor Yellow
    Write-Host "    dotnet run --project `"$signTool`" -- keygen `"$KeyPath`""
    exit 1
}
Write-Host "Signing latest.json ..." -NoNewline
& dotnet run --project $signTool --verbosity quiet -- sign $KeyPath $manifestPath
if ($LASTEXITCODE -ne 0) {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "ERROR: manifest signing failed - not publishing." -ForegroundColor Red
    exit 1
}
Write-Host " done -> latest.json.sig" -ForegroundColor Green

# --- 6. What the human still has to do --------------------------------------------------------
# Order matters: the .exe must be downloadable BEFORE latest.json advertises it, or clients that
# poll in the gap will try to download a URL that 404s.
Write-Host ""
Write-Host "NEXT STEPS - do them in this order:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Create the GitHub Release and upload the installer:"
Write-Host "       https://github.com/yogendra-singh-rathore/ovlox_encoder_releases/releases/new" -ForegroundColor Blue
Write-Host "       Tag    : v$Version        (create it on publish)"
Write-Host "       Title  : v$Version"
Write-Host "       Attach : $installer"
Write-Host "       Body   : the notes below + the SHA-256 above"
Write-Host ""
Write-Host "  2. Confirm the download URL works (paste it in a browser):"
Write-Host "       $($manifest.url)" -ForegroundColor Blue
Write-Host ""
Write-Host "  3. ONLY THEN publish the manifest + its signature, so no client sees a 404:"
Write-Host "       git -C `"$repoRoot`" add latest.json latest.json.sig"
Write-Host "       git -C `"$repoRoot`" commit -m `"Release v$Version`""
Write-Host "       git -C `"$repoRoot`" push"
Write-Host ""
Write-Host "  Release notes:"
foreach ($n in $Notes) { Write-Host "    - $n" }
Write-Host ""
