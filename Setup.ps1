#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs WoW addon management commands to PowerShell profile.

.DESCRIPTION
    Copies WoW management scripts to PowerShell profile directory and adds
    initialization to profile. Can be run locally or directly from URL.
    
    After installation, the following commands are available:
    - Wow-Download (Invoke-WowDownload) - Sync WTF from Azure
    - Wow-Upload (Invoke-WowUpload) - Upload WTF to Azure
    
    This script is idempotent - safe to run multiple times.

.EXAMPLE
    # Local installation
    ./Setup.ps1
    
.EXAMPLE
    # Remote installation (if hosted in Azure)
    iex (irm https://stprofilewus3.blob.core.windows.net/wow-config/Setup.ps1)

.OUTPUTS
    None - Installs scripts and configures profile
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WoW Addon Management Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get profile directory
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$wowScriptsDir = Join-Path $profileDir "Scripts" "WoW"

Write-Host "Profile Directory: " -NoNewline
Write-Host $profileDir -ForegroundColor Yellow
Write-Host "Target Directory: " -NoNewline
Write-Host $wowScriptsDir -ForegroundColor Yellow
Write-Host ""

# Create Scripts/WoW directory if it doesn't exist
if (-not (Test-Path $wowScriptsDir)) {
    Write-Host "Creating Scripts/WoW directory..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $wowScriptsDir -Force | Out-Null
    Write-Host "  ✓ Directory created" -ForegroundColor Green
} else {
    Write-Host "Scripts/WoW directory exists" -ForegroundColor Gray
}
Write-Host ""

# Determine source directory (where this script is running from)
$sourceDir = Join-Path $PSScriptRoot "Scripts" "WoW"

if (-not (Test-Path $sourceDir)) {
    Write-Host "Error: Scripts/WoW directory not found in: $PSScriptRoot" -ForegroundColor Red
    Write-Host "Please ensure you're running this script from the addonmanager repository root." -ForegroundColor Red
    exit 1
}

# Copy all WoW scripts to profile directory
Write-Host "Installing WoW management scripts..." -ForegroundColor Cyan

$scriptFiles = Get-ChildItem -Path $sourceDir -Filter "*.ps1" -File

foreach ($file in $scriptFiles) {
    $destPath = Join-Path $wowScriptsDir $file.Name
    
    try {
        Copy-Item -Path $file.FullName -Destination $destPath -Force
        Write-Host "  ✓ $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to copy $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Add initialization to profile if not already present
$profilePath = $global:PROFILE.CurrentUserAllHosts

Write-Host "Configuring PowerShell profile..." -ForegroundColor Cyan

# Create profile file if it doesn't exist
if (-not (Test-Path $profilePath)) {
    Write-Host "  Creating profile file..." -ForegroundColor Gray
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

# Read current profile content
$profileContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue

# Check if WoW initialization is already present
if ($profileContent -match 'Initialize-WowProfile\.ps1') {
    Write-Host "  ℹ WoW initialization already present in profile" -ForegroundColor Yellow
} else {
    Write-Host "  Adding WoW initialization to profile..." -ForegroundColor Gray
    
    $initBlock = @"

# Initialize WoW addon management
`$wowInitScript = Join-Path `$PSScriptRoot "Scripts/WoW/Initialize-WowProfile.ps1"
if (Test-Path `$wowInitScript) {
    . `$wowInitScript
}
"@
    
    Add-Content -Path $profilePath -Value $initBlock -Encoding UTF8
    Write-Host "  ✓ Profile updated" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell or run: " -NoNewline -ForegroundColor White
Write-Host ". `$PROFILE" -ForegroundColor Yellow
Write-Host "  2. Run " -NoNewline -ForegroundColor White
Write-Host "Wow-Download" -NoNewline -ForegroundColor Yellow
Write-Host " to sync your WTF configuration" -ForegroundColor White
Write-Host "  3. Or run " -NoNewline -ForegroundColor White
Write-Host "Wow-Upload" -NoNewline -ForegroundColor Yellow
Write-Host " to upload your current configuration" -ForegroundColor White
Write-Host ""
Write-Host "Available commands:" -ForegroundColor Cyan
Write-Host "  Wow-Download (Invoke-WowDownload) - Sync WTF from Azure" -ForegroundColor Gray
Write-Host "  Wow-Upload (Invoke-WowUpload)     - Upload WTF to Azure" -ForegroundColor Gray
Write-Host ""
