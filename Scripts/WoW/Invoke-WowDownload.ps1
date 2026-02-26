#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Downloads and syncs WTF configuration from Azure Blob Storage.

.DESCRIPTION
    Syncs WoW addon configuration from Azure:
    1. Loads wow.json configuration
    2. Validates Azure resources exist (fails fast if not)
    3. Resolves version (latest or specific)
    4. Preserves Config.wtf to temp location
    5. Deletes WTF folder contents
    6. Downloads all files from Azure using az CLI
    7. Restores Config.wtf
    8. Installs addons from GitHub via Get-Addons
    
    Uses complete replacement strategy - no file comparison.
    Supports versioned downloads — each Wow-Upload creates a new version.

.PARAMETER Installation
    WoW installation to sync (retail, classic, classicCata, beta, ptr, all)
    Default: all

.PARAMETER Version
    Version to download. Use a number (e.g. 1, 2, 3) for a specific version,
    or 'latest' to automatically use the most recent version.
    Default: latest

.PARAMETER WhatIf
    Preview changes without applying

.EXAMPLE
    Invoke-WowDownload
    Sync latest version of all detected installations

.EXAMPLE
    Invoke-WowDownload -Version 3
    Sync version 3

.EXAMPLE
    Wow-Download
    Using alias to sync all installations
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Version = 'latest',

    [Parameter(Position = 1)]
    [ValidateSet('retail', 'classic', 'classicCata', 'beta', 'ptr', 'all')]
    [string]$Installation = 'all',
    
    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WoW Configuration Sync" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration (create if missing)
Write-Host "Loading configuration..." -ForegroundColor Cyan

$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$configScript = Join-Path $profileDir "Scripts" "WoW" "Get-WowConfig.ps1"

if (-not (Test-Path $configScript)) {
    Write-Host "Error: Get-WowConfig.ps1 not found at: $configScript" -ForegroundColor Red
    return
}

try {
    $config = & $configScript
    Write-Host "  ✓ wow.json loaded" -ForegroundColor Green
}
catch {
    # wow.json doesn't exist, create it
    Write-Host "  ℹ wow.json not found, creating..." -ForegroundColor Yellow
    Write-Host ""
    
    $newConfigScript = Join-Path $profileDir "Scripts" "WoW" "New-WowConfig.ps1"
    
    if (-not (Test-Path $newConfigScript)) {
        Write-Host "Error: New-WowConfig.ps1 not found at: $newConfigScript" -ForegroundColor Red
        return
    }
    
    & $newConfigScript
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Configuration creation failed" -ForegroundColor Red
        return
    }
    
    # Load the newly created config
    $config = & $configScript
    Write-Host ""
}

Write-Host "  ✓ WoW installation found: $($config.wowRoot)" -ForegroundColor Green
Write-Host ""

# Verify Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Azure CLI not found" -ForegroundColor Red
    Write-Host "Please install Azure CLI: https://aka.ms/azure-cli" -ForegroundColor Red
    return
}

# Verify logged into Azure
$azAccount = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Not logged into Azure" -ForegroundColor Red
    Write-Host "Please run: az login" -ForegroundColor Red
    Write-Host "Then run: az account set --subscription $($config.azureSubscription)" -ForegroundColor Red
    return
}

# Verify subscription
az account set --subscription $config.azureSubscription 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to set Azure subscription: $($config.azureSubscription)" -ForegroundColor Red
    return
}

# Verify storage account exists (fail fast)
Write-Host "Verifying Azure resources..." -ForegroundColor Cyan
$storageCheck = az storage account show `
    --name $config.azureStorageAccount `
    --resource-group $config.azureResourceGroup `
    2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Azure storage not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Azure storage account '$($config.azureStorageAccount)' does not exist." -ForegroundColor Yellow
    Write-Host "Run Upload.ps1 from the addonmanager repository to initialize Azure resources." -ForegroundColor Yellow
    Write-Host ""
    return
}

Write-Host "  ✓ Azure storage account verified" -ForegroundColor Green
Write-Host ""

# Resolve version
Write-Host "Resolving version..." -ForegroundColor Cyan
$storageKey = az storage account keys list `
    --account-name $config.azureStorageAccount `
    --resource-group $config.azureResourceGroup `
    --query "[0].value" --output tsv 2>&1

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($storageKey)) {
    Write-Host "  ✗ Failed to retrieve storage key" -ForegroundColor Red
    return
}

$blobListJson = az storage blob list `
    --account-name $config.azureStorageAccount `
    --account-key $storageKey `
    --container-name $config.azureContainer `
    --output json 2>&1

$availableVersions = @()
if ($LASTEXITCODE -eq 0) {
    try {
        $blobs = $blobListJson | ConvertFrom-Json
        $availableVersions = $blobs | ForEach-Object {
            if ($_.name -match '^v(\d+)/') { [int]$Matches[1] }
        } | Sort-Object -Unique
    } catch {}
}

if (-not $availableVersions -or $availableVersions.Count -eq 0) {
    Write-Host "  ✗ No versions found in storage" -ForegroundColor Red
    Write-Host "  Run Wow-Upload first to create a version." -ForegroundColor Yellow
    return
}

$latestVersion = ($availableVersions | Measure-Object -Maximum).Maximum

if ($Version -eq 'latest') {
    $resolvedVersion = $latestVersion
    Write-Host "  ✓ Latest version: v$resolvedVersion" -ForegroundColor Green
} else {
    $resolvedVersion = [int]$Version
    if ($resolvedVersion -notin $availableVersions) {
        Write-Host "  ✗ Version v$resolvedVersion not found" -ForegroundColor Red
        Write-Host "  Available versions: $(($availableVersions | ForEach-Object { "v$_" }) -join ', ')" -ForegroundColor Yellow
        return
    }
    Write-Host "  ✓ Using version: v$resolvedVersion" -ForegroundColor Green
}
Write-Host ""

# Determine installations to sync
$installationsToSync = @()

if ($Installation -eq 'all') {
    $installationsToSync = $config.installations.PSObject.Properties.Name
} else {
    if ($config.installations.PSObject.Properties.Name -contains $Installation) {
        $installationsToSync = @($Installation)
    } else {
        Write-Host "Error: Installation '$Installation' not found in configuration" -ForegroundColor Red
        return
    }
}

Write-Host "Detected Installations:" -ForegroundColor Cyan
foreach ($key in $config.installations.PSObject.Properties.Name) {
    if ($installationsToSync -contains $key) {
        Write-Host "  ✓ $($config.installations.$key.description)" -ForegroundColor Green
    } else {
        Write-Host "  ℹ $($config.installations.$key.description) - not selected" -ForegroundColor Gray
    }
}
Write-Host ""

# Sync each installation
foreach ($key in $installationsToSync) {
    $installInfo = $config.installations.$key
    $installPath = Join-Path $config.wowRoot $installInfo.path
    $wtfPath = Join-Path $installPath "WTF"
    $configWtfPath = Join-Path $wtfPath "Config.wtf"
    
    Write-Host "Syncing: $($installInfo.description) ($($installInfo.path)) - v$resolvedVersion" -ForegroundColor Cyan
    
    if ($WhatIf) {
        Write-Host "  [WhatIf] Would sync WTF folder" -ForegroundColor Yellow
        continue
    }
    
    # Preserve Config.wtf
    $tempConfigPath = $null
    if (Test-Path $configWtfPath) {
        Write-Host "  Preserving Config.wtf..." -ForegroundColor Cyan
        $tempConfigPath = Join-Path ([IO.Path]::GetTempPath()) "Config.wtf.$key.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item -Path $configWtfPath -Destination $tempConfigPath -Force
        Write-Host "    ✓ Saved to temp" -ForegroundColor Green
    }
    
    # Clear WTF folder
    Write-Host "  Clearing WTF folder..." -ForegroundColor Cyan
    if (Test-Path $wtfPath) {
        Remove-Item -Path (Join-Path $wtfPath '*') -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Path $wtfPath -Force | Out-Null
    }
    Write-Host "    ✓ Cleared" -ForegroundColor Green
    
    # Download from Azure
    Write-Host "  Downloading from Azure (v$resolvedVersion)..." -ForegroundColor Cyan
    $blobPrefix = "v$resolvedVersion/$key/WTF"
    Write-Host "    Source: $($config.azureStorageAccount)/$($config.azureContainer)/$blobPrefix" -ForegroundColor Gray
    
    # Download to temp location to handle path stripping
    $tempDownloadDir = Join-Path ([IO.Path]::GetTempPath()) "wow-download-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDownloadDir -Force | Out-Null
    Write-Host "    Temp: $tempDownloadDir" -ForegroundColor Gray
    
    try {
        # Let az CLI stream progress to console (don't capture stdout)
        Write-Host ""
        az storage blob download-batch `
            --account-name $config.azureStorageAccount `
            --account-key $storageKey `
            --source $config.azureContainer `
            --destination $tempDownloadDir `
            --pattern "$blobPrefix/*" `
            --output none
        Write-Host ""
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Download failed" -ForegroundColor Red
            
            # Restore Config.wtf if we saved it
            if ($tempConfigPath -and (Test-Path $tempConfigPath)) {
                Copy-Item -Path $tempConfigPath -Destination $configWtfPath -Force
                Remove-Item -Path $tempConfigPath -Force
            }
            continue
        }
        
        # Move files from temp/v{N}/retail/WTF/* to $wtfPath
        $downloadedWtfPath = Join-Path $tempDownloadDir "v$resolvedVersion" $key "WTF"
        if (Test-Path $downloadedWtfPath) {
            $items = Get-ChildItem -Path $downloadedWtfPath -Force
            $fileCount = (Get-ChildItem -Path $downloadedWtfPath -Recurse -File -Force).Count
            foreach ($item in $items) {
                $destPath = Join-Path $wtfPath $item.Name
                Move-Item -Path $item.FullName -Destination $destPath -Force
            }
            Write-Host "    ✓ Downloaded $fileCount files" -ForegroundColor Green
        } else {
            Write-Host "    ⚠ No files downloaded" -ForegroundColor Yellow
        }
    }
    finally {
        # Clean up temp download directory
        if (Test-Path $tempDownloadDir) {
            Remove-Item -Path $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Restore Config.wtf
    if ($tempConfigPath -and (Test-Path $tempConfigPath)) {
        Write-Host "  Restoring Config.wtf..." -ForegroundColor Cyan
        Copy-Item -Path $tempConfigPath -Destination $configWtfPath -Force
        Remove-Item -Path $tempConfigPath -Force
        Write-Host "    ✓ Restored" -ForegroundColor Green
    }
    
    Write-Host ""
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "WTF Sync Complete! (v$resolvedVersion)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Install/update addons from GitHub
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$getAddonsScript = Join-Path $profileDir "Scripts" "WoW" "Invoke-GetAddons.ps1"

if (Test-Path $getAddonsScript) {
    & $getAddonsScript -Installation $Installation -SyncOnly
} else {
    Write-Host "⚠ Invoke-GetAddons.ps1 not found — run Setup.ps1 to enable addon installs" -ForegroundColor Yellow
}
