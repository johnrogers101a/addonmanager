#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates initial wow.json configuration file.

.DESCRIPTION
    Interactive wizard that:
    1. Prompts for WoW installation root directory
    2. Auto-detects installed WoW versions
    3. Generates wow.json in PowerShell profile directory
    
    Safe to run multiple times - will prompt before overwriting.

.EXAMPLE
    & ".\New-WowConfig.ps1"
    Interactive configuration creation

.OUTPUTS
    None - Creates wow.json file
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WoW Configuration Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get profile directory
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$configPath = Join-Path $profileDir "wow.json"

# Check if config already exists
if (Test-Path $configPath) {
    Write-Host "wow.json already exists at: $configPath" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite existing configuration? (y/N)"
    
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Host "Configuration creation cancelled." -ForegroundColor Yellow
        return
    }
}

# Prompt for WoW root directory with retry loop
$wowRoot = $null
$installations = $null

while (-not $installations) {
    Write-Host "Enter WoW installation root directory:" -ForegroundColor Cyan
    
    $defaultWowRoot = if ($IsWindows -or $env:OS -match 'Windows') {
        "C:\Program Files (x86)\World of Warcraft"
    } elseif ($IsMacOS) {
        "/Applications/World of Warcraft"
    } else {
        # Linux: common Lutris path
        Join-Path $HOME "Games" "world-of-warcraft"
    }
    
    Write-Host "  Default: $defaultWowRoot" -ForegroundColor Gray
    Write-Host "  (Press Ctrl+C to cancel)" -ForegroundColor Gray
    $input = Read-Host "WoW Root"
    
    if ([string]::IsNullOrWhiteSpace($input)) {
        $wowRoot = $defaultWowRoot
    } else {
        $wowRoot = $input
    }
    
    # Validate WoW root exists
    if (-not (Test-Path $wowRoot)) {
        Write-Host "  ✗ Directory not found: $wowRoot" -ForegroundColor Red
        Write-Host ""
        continue
    }
    
    Write-Host ""
    Write-Host "Detecting WoW installations..." -ForegroundColor Cyan
    
    # Detect installations
    $detectScript = Join-Path $PSScriptRoot "Get-WowInstallations.ps1"
    $installations = & $detectScript -WowRoot $wowRoot
    
    if ($installations.Count -eq 0) {
        Write-Host "  ✗ No WoW installations detected in: $wowRoot" -ForegroundColor Red
        Write-Host "    Expected folders: _retail_, _classic_, _classic_era_, _beta_, _ptr_" -ForegroundColor Gray
        Write-Host ""
        $installations = $null
        continue
    }
    
    Write-Host "  Detected $($installations.Count) installation(s):" -ForegroundColor Green
    foreach ($key in $installations.Keys) {
        Write-Host "    ✓ $($installations[$key].description)" -ForegroundColor Green
    }
}

# Get Azure info for config
$azSubscription = "unknown"
$azEmail = "user"
try {
    $azAccountJson = az account show --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $azAccountObj = $azAccountJson | ConvertFrom-Json
        $azSubscription = $azAccountObj.name
        $azEmail = $azAccountObj.user.name
    }
} catch {}

# Derive storage account name from email
$username = ($azEmail -split '@')[0] -replace '[^a-z0-9]', ''
$maxUsernameLen = 15
if ($username.Length -gt $maxUsernameLen) {
    $username = $username.Substring(0, $maxUsernameLen)
}
$storageAccountName = "st${username}wowwus3"

# Build configuration object
$config = @{
    wowRoot              = $wowRoot
    installations        = $installations
    azureSubscription    = $azSubscription
    azureResourceGroup   = "rg-wow-profile"
    azureStorageAccount  = $storageAccountName
    azureContainer       = "wow-config"
    azureLocation        = "westus3"
    excludeFiles         = @("Config.wtf")
}

# Save configuration
Write-Host ""
Write-Host "Saving configuration to: $configPath" -ForegroundColor Cyan

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8

Write-Host "  ✓ Configuration saved" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Configuration Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run Wow-Download to sync configuration from Azure" -ForegroundColor White
Write-Host "  2. Or configure your addons and run Wow-Upload" -ForegroundColor White
Write-Host ""
