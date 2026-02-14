#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uploads WoW addon configuration to Azure Blob Storage.

.DESCRIPTION
    Uploads WTF configurations to Azure:
    1. Creates Azure resources if they don't exist (idempotent)
    2. Deletes existing blobs in container
    3. Excludes Config.wtf from upload
    4. Uploads all files using Azure CLI

.EXAMPLE
    Invoke-WowUpload
    Upload all WTF configurations to Azure

.EXAMPLE
    Wow-Upload -Verbose
    Upload with detailed path output

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

# Resolve profile directory
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
Write-Verbose "Profile directory: $profileDir"

if (-not (Test-Path $profileDir)) {
    Write-Host "Error: Profile directory not found: $profileDir" -ForegroundColor Red
    exit 1
}
Write-Verbose "  ✓ exists"

$scriptsDir = Join-Path $profileDir "Scripts/WoW"
Write-Verbose "Scripts directory: $scriptsDir"

if (-not (Test-Path $scriptsDir)) {
    Write-Host "Error: Scripts directory not found: $scriptsDir" -ForegroundColor Red
    Write-Host "Run Setup.ps1 from the addonmanager repository." -ForegroundColor Yellow
    exit 1
}
Write-Verbose "  ✓ exists"

# Resolve config script paths
$configScript = Join-Path $scriptsDir "Get-WowConfig.ps1"
Write-Verbose "Config script: $configScript"

if (-not (Test-Path $configScript)) {
    Write-Host "Error: Get-WowConfig.ps1 not found at: $configScript" -ForegroundColor Red
    exit 1
}
Write-Verbose "  ✓ exists"

$newConfigScript = Join-Path $scriptsDir "New-WowConfig.ps1"
Write-Verbose "New config script: $newConfigScript"

if (-not (Test-Path $newConfigScript)) {
    Write-Host "Error: New-WowConfig.ps1 not found at: $newConfigScript" -ForegroundColor Red
    exit 1
}
Write-Verbose "  ✓ exists"

# Resolve temp directory (macOS uses TMPDIR, not TEMP)
$tempBase = if ($env:TMPDIR) { $env:TMPDIR } elseif ($env:TEMP) { $env:TEMP } else { "/tmp" }
$tempBase = $tempBase.TrimEnd('/')
Write-Verbose "Temp base directory: $tempBase"

if (-not (Test-Path $tempBase)) {
    Write-Host "Error: Temp directory not found: $tempBase" -ForegroundColor Red
    exit 1
}
Write-Verbose "  ✓ exists"

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
$config = & $configScript

if (-not $config) {
    Write-Host ""
    Write-Host "No WoW configuration found. Let's create one now..." -ForegroundColor Cyan
    Write-Host ""
    
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
    Write-Host "Error: No WoW installations configured in wow.json" -ForegroundColor Red
    Write-Host "Please run New-WowConfig to set up your configuration." -ForegroundColor Red
    exit 1
}

$wowRoot = $config.wowRoot
Write-Verbose "WoW root: $wowRoot"

if (-not $wowRoot) {
    Write-Host "Error: WoW root not configured in wow.json" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $wowRoot)) {
    Write-Host "Error: WoW root directory not found: $wowRoot" -ForegroundColor Red
    Write-Host "Please run New-WowConfig to update your configuration." -ForegroundColor Yellow
    exit 1
}
Write-Verbose "  ✓ exists"

$installCount = ($config.installations.PSObject.Properties | Measure-Object).Count
Write-Host "Found $installCount WoW installation(s) to upload" -ForegroundColor Cyan
Write-Host ""

# Upload each installation
$totalFiles = 0

foreach ($installProp in $config.installations.PSObject.Properties) {
    $installKey = $installProp.Name
    $installInfo = $installProp.Value
    $installPath = Join-Path $wowRoot $installInfo.path
    $wtfPath = Join-Path $installPath "WTF"
    
    Write-Verbose "[$installKey]"
    Write-Verbose "  installInfo.path: $($installInfo.path)"
    Write-Verbose "  installPath (resolved): $installPath"
    Write-Verbose "  wtfPath (resolved): $wtfPath"
    
    # Validate installation path exists
    if (-not (Test-Path $installPath)) {
        Write-Host "  ⚠ Installation path not found: $installPath, skipping $installKey" -ForegroundColor Yellow
        continue
    }
    Write-Verbose "  ✓ installPath exists"
    
    # Validate WTF folder exists
    if (-not (Test-Path $wtfPath)) {
        Write-Host "  ⚠ WTF folder not found: $wtfPath, skipping $installKey" -ForegroundColor Yellow
        continue
    }
    Write-Verbose "  ✓ wtfPath exists"
    
    Write-Host "Uploading: $installKey" -ForegroundColor Cyan
    
    # Generate addons.json before upload
    $updateAddonsScript = Join-Path $scriptsDir "Update-AddonsJson.ps1"
    Write-Verbose "  Update-AddonsJson script: $updateAddonsScript"
    
    if (Test-Path $updateAddonsScript) {
        Write-Verbose "  ✓ exists"
        Write-Host "  Generating addons.json..." -ForegroundColor Gray
        try {
            $addonCount = & $updateAddonsScript -WowRoot $wowRoot -Installation $installInfo.path -InstallationKey $installKey
            Write-Host "  ✓ addons.json created with $addonCount addons" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠ Failed to generate addons.json: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  Continuing with upload..." -ForegroundColor Gray
        }
    } else {
        Write-Host "  ⚠ Update-AddonsJson.ps1 not found at: $updateAddonsScript" -ForegroundColor Yellow
    }
    
    # Create temp directory for upload (excluding Config.wtf)
    $tempUploadDir = Join-Path $tempBase "wow-upload-$(Get-Random)"
    Write-Verbose "  tempUploadDir: $tempUploadDir"
    New-Item -ItemType Directory -Path $tempUploadDir -Force | Out-Null
    
    if (-not (Test-Path $tempUploadDir)) {
        Write-Host "  ✗ Failed to create temp directory: $tempUploadDir" -ForegroundColor Red
        continue
    }
    Write-Verbose "  ✓ tempUploadDir created"
    
    try {
        # Copy WTF contents to temp, excluding Config.wtf
        Write-Verbose "  Copying files to temp directory (excluding Config.wtf)..."
        
        $filesToCopy = Get-ChildItem -Path $wtfPath -File -Recurse -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -ne 'Config.wtf' }
        
        Write-Verbose "  Files to copy: $($filesToCopy.Count)"
        
        foreach ($file in $filesToCopy) {
            $relativePath = $file.FullName.Replace($wtfPath, '').TrimStart([IO.Path]::DirectorySeparatorChar)
            $destFile = Join-Path $tempUploadDir $relativePath
            $destDir = Split-Path -Parent $destFile
            
            Write-Verbose "    src: $($file.FullName)"
            Write-Verbose "    rel: $relativePath"
            Write-Verbose "    dst: $destFile"
            
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $destFile -Force
        }
        
        $fileCount = (Get-ChildItem -Path $tempUploadDir -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        Write-Verbose "  Files in temp dir: $fileCount"
        
        if ($fileCount -eq 0) {
            Write-Host "  ℹ No files to upload" -ForegroundColor Gray
            continue
        }
        
        Write-Host "  Uploading $fileCount files..." -ForegroundColor Gray
        
        $blobPrefix = "$installKey/WTF"
        Write-Verbose "  blob prefix: $blobPrefix"
        Write-Verbose "  source: $tempUploadDir"
        Write-Verbose "  destination: $container"
        
        az storage blob upload-batch `
            --account-name $storageAccount `
            --account-key $storageKey `
            --destination $container `
            --source $tempUploadDir `
            --destination-path $blobPrefix `
            --output none
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Uploaded $fileCount files" -ForegroundColor Green
            $totalFiles += $fileCount
        } else {
            Write-Host "  ✗ Upload failed" -ForegroundColor Red
        }
    }
    finally {
        Write-Verbose "  Cleaning up temp: $tempUploadDir"
        if (Test-Path $tempUploadDir) {
            Remove-Item -Path $tempUploadDir -Recurse -Force -ErrorAction SilentlyContinue
        }
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
