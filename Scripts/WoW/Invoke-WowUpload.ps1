#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uploads WoW addon configuration to Azure Blob Storage.

.DESCRIPTION
    Uploads WTF configurations from addonmanager repository to Azure:
    1. Creates Azure resources if they don't exist (idempotent)
    2. Scans WTF subfolders in repository
    3. Deletes existing blobs in container
    4. Generates addons.json for each configuration
    5. Excludes Config.wtf from upload
    6. Uploads all files using Azure CLI
    
    This script uses the repository as source of truth.

.EXAMPLE
    Invoke-WowUpload
    Upload all WTF configurations to Azure

.EXAMPLE
    Wow-Upload
    Using alias to upload configurations

.NOTES
    Requires Azure CLI and authentication:
    - az login
    - az account set --subscription 4js
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WoW Configuration Upload" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Azure configuration
$subscription = "4js"
$resourceGroup = "rg-wow-profile"
$storageAccount = "stwowprofilewus3"
$container = "wow-config"
$location = "westus3"

# Verify Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Azure CLI not found" -ForegroundColor Red
    Write-Host "Please install Azure CLI: https://aka.ms/azure-cli" -ForegroundColor Red
    exit 1
}

# Verify logged into Azure
Write-Host "Verifying Azure authentication..." -ForegroundColor Cyan
$azAccount = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Not logged into Azure" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run:" -ForegroundColor Yellow
    Write-Host "  az login" -ForegroundColor White
    Write-Host "  az account set --subscription $subscription" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Set subscription
az account set --subscription $subscription 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Failed to set subscription: $subscription" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Authenticated to Azure subscription: $subscription" -ForegroundColor Green
Write-Host ""

# Check if resource group exists, create if not
Write-Host "Checking Azure resource group..." -ForegroundColor Cyan
$rgExists = az group exists --name $resourceGroup 2>&1
if ($rgExists -eq 'false') {
    Write-Host "  Creating resource group: $resourceGroup" -ForegroundColor Yellow
    az group create --name $resourceGroup --location $location --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Resource group created" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to create resource group" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✓ Resource group exists" -ForegroundColor Green
}
Write-Host ""

# Check if storage account exists, create if not
Write-Host "Checking Azure storage account..." -ForegroundColor Cyan
$storageCheck = az storage account show `
    --name $storageAccount `
    --resource-group $resourceGroup `
    2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creating storage account: $storageAccount" -ForegroundColor Yellow
    Write-Host "  This may take a minute..." -ForegroundColor Gray
    
    az storage account create `
        --name $storageAccount `
        --resource-group $resourceGroup `
        --location $location `
        --sku Standard_LRS `
        --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Storage account created" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to create storage account" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✓ Storage account exists" -ForegroundColor Green
}
Write-Host ""

# Get storage account key
Write-Host "Retrieving storage account key..." -ForegroundColor Cyan
$storageKey = az storage account keys list `
    --account-name $storageAccount `
    --resource-group $resourceGroup `
    --query "[0].value" `
    --output tsv `
    2>&1

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($storageKey)) {
    Write-Host "  ✗ Failed to retrieve storage key" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Storage key retrieved" -ForegroundColor Green
Write-Host ""

# Check if container exists, create if not
Write-Host "Checking storage container..." -ForegroundColor Cyan
$containerCheck = az storage container exists `
    --account-name $storageAccount `
    --account-key $storageKey `
    --name $container `
    --output tsv `
    2>&1

if ($containerCheck -ne 'True') {
    Write-Host "  Creating container: $container" -ForegroundColor Yellow
    
    az storage container create `
        --account-name $storageAccount `
        --account-key $storageKey `
        --name $container `
        --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Container created" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to create container" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✓ Container exists" -ForegroundColor Green
}
Write-Host ""

# Delete existing blobs in container
Write-Host "Clearing existing configuration..." -ForegroundColor Cyan
$blobList = az storage blob list `
    --account-name $storageAccount `
    --account-key $storageKey `
    --container-name $container `
    --output json `
    2>&1

if ($LASTEXITCODE -eq 0) {
    try {
        $blobs = $blobList | ConvertFrom-Json
        if ($blobs.Count -gt 0) {
            Write-Host "  Deleting $($blobs.Count) existing blobs..." -ForegroundColor Gray
            
            az storage blob delete-batch `
                --account-name $storageAccount `
                --account-key $storageKey `
                --source $container `
                --output none
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ Existing blobs deleted" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Failed to delete some blobs" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ℹ No existing blobs to delete" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ℹ Container is empty" -ForegroundColor Gray
    }
} else {
    Write-Host "  ⚠ Could not list blobs" -ForegroundColor Yellow
}
Write-Host ""

# Load WoW configuration
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$configScript = Join-Path $profileDir "Scripts/WoW/Get-WowConfig.ps1"

if (-not (Test-Path $configScript)) {
    Write-Host "Error: Get-WowConfig.ps1 not found at: $configScript" -ForegroundColor Red
    exit 1
}

$config = & $configScript

if (-not $config) {
    Write-Host ""
    Write-Host "No WoW configuration found. Let's create one now..." -ForegroundColor Cyan
    Write-Host ""
    
    $newConfigScript = Join-Path $profileDir "Scripts/WoW/New-WowConfig.ps1"
    
    if (-not (Test-Path $newConfigScript)) {
        Write-Host "Error: New-WowConfig.ps1 not found at: $newConfigScript" -ForegroundColor Red
        exit 1
    }
    
    & $newConfigScript
    
    # Try loading again
    $config = & $configScript
    
    if (-not $config) {
        Write-Host "Error: Configuration creation failed or was cancelled." -ForegroundColor Red
        exit 1
    }
}

# Validate configuration
if (-not $config.installations) {
    Write-Host "Error: No WoW installations configured" -ForegroundColor Red
    Write-Host "Please run New-WowConfig to set up your configuration." -ForegroundColor Red
    exit 1
}

if (-not $config.wowRoot -or -not (Test-Path $config.wowRoot)) {
    Write-Host "Error: WoW root directory not found: $($config.wowRoot)" -ForegroundColor Red
    Write-Host "Please run New-WowConfig to update your configuration." -ForegroundColor Red
    exit 1
}

$installCount = ($config.installations.PSObject.Properties | Measure-Object).Count
Write-Host "Found $installCount WoW installation(s) to upload" -ForegroundColor Cyan
Write-Host ""

# Upload each installation
$totalFiles = 0

foreach ($installProp in $config.installations.PSObject.Properties) {
    $installKey = $installProp.Name
    $installInfo = $installProp.Value
    $installPath = Join-Path $config.wowRoot $installInfo.path
    $wtfPath = Join-Path $installPath "WTF"
    
    # Validate installation path exists
    if (-not (Test-Path $installPath)) {
        Write-Host "  ⚠ Installation path not found: $installPath, skipping $installKey" -ForegroundColor Yellow
        continue
    }
    
    # Validate WTF folder exists
    if (-not (Test-Path $wtfPath)) {
        Write-Host "  ⚠ WTF folder not found: $wtfPath, skipping $installKey" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Uploading: $installKey" -ForegroundColor Cyan
    
    # Count files (excluding Config.wtf)
    $files = Get-ChildItem -Path $wtfPath -File -Recurse -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -ne 'Config.wtf' }
    
    if (-not $files) {
        Write-Host "  ℹ No files to upload" -ForegroundColor Gray
        continue
    }
    
    Write-Host "  Uploading $($files.Count) files..." -ForegroundColor Gray
    
    # Upload to Azure
    $blobPrefix = "$installKey/WTF"
    
    az storage blob upload-batch `
        --account-name $storageAccount `
        --account-key $storageKey `
        --destination $container `
        --source $wtfPath `
        --destination-path $blobPrefix `
        --pattern "*" `
        --exclude-pattern "Config.wtf" `
        --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Uploaded $($files.Count) files" -ForegroundColor Green
        $totalFiles += $files.Count
    } else {
        Write-Host "  ✗ Upload failed" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Upload Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Total files uploaded: $totalFiles" -ForegroundColor Cyan
Write-Host "Storage Account: $storageAccount" -ForegroundColor Gray
Write-Host "Container: $container" -ForegroundColor Gray
Write-Host ""
Write-Host "Users can now run Update-Wow to sync configurations" -ForegroundColor White
Write-Host ""
