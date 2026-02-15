#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs WoW addon management commands to PowerShell profile.

.DESCRIPTION
    Copies WoW management scripts to PowerShell profile directory and registers
    WoW commands in Initialize-PowerShellProfile.ps1 using the same function
    wrapper pattern as existing profile commands.
    
    After installation, the following commands are available:
    - Wow-Download (Invoke-WowDownload) - Sync WTF from Azure
    - Wow-Upload (Invoke-WowUpload) - Upload WTF to Azure
    
    Cross-platform: works on Windows, macOS, and Linux.
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

# Register WoW commands in Initialize-PowerShellProfile.ps1
Write-Host "Registering WoW commands..." -ForegroundColor Cyan

$initScript = Join-Path $profileDir "Scripts" "Profile" "Initialize-PowerShellProfile.ps1"

if (-not (Test-Path $initScript)) {
    Write-Host "  ⚠ Initialize-PowerShellProfile.ps1 not found at: $initScript" -ForegroundColor Yellow
    Write-Host "  WoW scripts installed but commands not registered." -ForegroundColor Yellow
    Write-Host "  You can call scripts directly from: $wowScriptsDir" -ForegroundColor Yellow
} else {
    $initContent = Get-Content -Path $initScript -Raw

    if ($initContent -match 'Invoke-WowDownload') {
        Write-Host "  ℹ WoW commands already registered" -ForegroundColor Yellow
    } else {
        # Append WoW command functions before Show-Commands call
        $wowBlock = @'

# WoW addon management commands
function Invoke-WowDownload {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-WowDownload.ps1"
    & $scriptPath @args
}

function Invoke-WowUpload {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-WowUpload.ps1"
    & $scriptPath @args
}

function New-WowConfig {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "New-WowConfig.ps1"
    & $scriptPath @args
}

function Get-WowConfig {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Get-WowConfig.ps1"
    & $scriptPath @args
}

function Get-WowInstallations {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Get-WowInstallations.ps1"
    & $scriptPath @args
}

function Get-InstalledAddons {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Get-InstalledAddons.ps1"
    & $scriptPath @args
}

function Update-AddonsJson {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Update-AddonsJson.ps1"
    & $scriptPath @args
}

Set-Alias -Name Wow-Download -Value Invoke-WowDownload
Set-Alias -Name Wow-Upload -Value Invoke-WowUpload
'@
        # Insert before "# Display loaded custom commands" line
        if ($initContent -match '(?m)^# Display loaded custom commands') {
            $initContent = $initContent -replace '(?m)^# Display loaded custom commands', "$wowBlock`n`n# Display loaded custom commands"
        } else {
            # Fallback: append to end
            $initContent += $wowBlock
        }

        Set-Content -Path $initScript -Value $initContent -Encoding UTF8 -NoNewline
        Write-Host "  ✓ WoW commands registered in Initialize-PowerShellProfile.ps1" -ForegroundColor Green
    }
}

# Create wrapper scripts in Scripts/Profile for Show-Commands discovery
Write-Host ""
Write-Host "Creating wrapper scripts in Scripts/Profile..." -ForegroundColor Cyan

$profileScriptsDir = Join-Path $profileDir "Scripts" "Profile"

# Ensure Scripts/Profile exists
if (-not (Test-Path $profileScriptsDir)) {
    New-Item -ItemType Directory -Path $profileScriptsDir -Force | Out-Null
}

# Create Invoke-WowDownload wrapper
$wowDownloadWrapper = @'
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sync WTF configuration from Azure

.DESCRIPTION
    Downloads and syncs WTF configuration from Azure Blob Storage.
#>
param()
$wowScript = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-WowDownload.ps1"
& $wowScript @args
'@

$wowDownloadPath = Join-Path $profileScriptsDir "Invoke-WowDownload.ps1"
$wowDownloadWrapper | Set-Content -Path $wowDownloadPath -Encoding UTF8
Write-Host "  ✓ Invoke-WowDownload.ps1" -ForegroundColor Green

# Create Invoke-WowUpload wrapper
$wowUploadWrapper = @'
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Upload WTF configuration to Azure

.DESCRIPTION
    Uploads WTF configuration to Azure Blob Storage.
#>
param()
$wowScript = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-WowUpload.ps1"
& $wowScript @args
'@

$wowUploadPath = Join-Path $profileScriptsDir "Invoke-WowUpload.ps1"
$wowUploadWrapper | Set-Content -Path $wowUploadPath -Encoding UTF8
Write-Host "  ✓ Invoke-WowUpload.ps1" -ForegroundColor Green

# Clean up old dot-source init from profile.ps1 if present
$profilePath = $global:PROFILE.CurrentUserAllHosts
if (Test-Path $profilePath) {
    $profileContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -match 'Initialize-WowProfile\.ps1') {
        Write-Host ""
        Write-Host "Cleaning up old profile initialization..." -ForegroundColor Cyan
        # Remove the old WoW init block from profile.ps1
        $profileContent = $profileContent -replace '(?ms)\r?\n# Initialize WoW addon management\r?\n.*?Initialize-WowProfile\.ps1.*?\r?\n\}\r?\n?', ''
        Set-Content -Path $profilePath -Value $profileContent.TrimEnd() -Encoding UTF8
        Write-Host "  ✓ Removed old dot-source init from profile.ps1" -ForegroundColor Green
    }
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
