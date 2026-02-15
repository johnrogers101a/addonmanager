#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uploads WoW addon configuration to Azure Blob Storage.

.DESCRIPTION
    Uploads WTF configurations to Azure with versioning:
    1. Creates Azure resources if they don't exist (idempotent)
    2. Determines next version number from existing versions
    3. Uploads all files to versioned prefix (v1, v2, etc.)
    4. Excludes Config.wtf from upload
    
    Each upload creates a new version. Use Wow-Download -Version N to restore.

.EXAMPLE
    Invoke-WowUpload
    Upload all WTF configurations as a new version

.EXAMPLE
    Wow-Upload -Verbose
    Upload with detailed path output

.NOTES
    Requires Azure CLI and authentication.
    Storage account and subscription are read from wow.json.
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

$scriptsDir = Join-Path $profileDir "Scripts" "WoW"

if (-not (Test-Path $scriptsDir)) {
    Write-Host "Error: Scripts directory not found: $scriptsDir" -ForegroundColor Red
    Write-Host "Run Setup.ps1 from the addonmanager repository." -ForegroundColor Yellow
    exit 1
}

# Load configuration from wow.json
$configScript = Join-Path $scriptsDir "Get-WowConfig.ps1"
if (-not (Test-Path $configScript)) {
    Write-Host "Error: Get-WowConfig.ps1 not found" -ForegroundColor Red
    exit 1
}

$config = & $configScript
if (-not $config) {
    Write-Host "Error: Failed to load wow.json. Run Setup.ps1 first." -ForegroundColor Red
    exit 1
}

$subscription = $config.azureSubscription
$resourceGroup = $config.azureResourceGroup
$storageAccount = $config.azureStorageAccount
$container = $config.azureContainer
$location = if ($config.azureLocation) { $config.azureLocation } else { "westus3" }

Write-Verbose "Subscription: $subscription"
Write-Verbose "Resource group: $resourceGroup"
Write-Verbose "Storage account: $storageAccount"
Write-Verbose "Container: $container"
Write-Verbose "Location: $location"

# Resolve temp directory (cross-platform)
$tempBase = [IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar)

# Verify Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Azure CLI not found" -ForegroundColor Red
    exit 1
}

# Verify logged into Azure
Write-Host "Verifying Azure authentication..." -ForegroundColor Cyan
$azAccount = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Not logged into Azure" -ForegroundColor Red
    Write-Host "  Run: az login" -ForegroundColor White
    exit 1
}

# Set subscription
az account set --subscription $subscription 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Failed to set subscription: $subscription" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Authenticated: $subscription" -ForegroundColor Green
Write-Host ""

# Check if resource group exists, create if not
Write-Host "Checking Azure resources..." -ForegroundColor Cyan
$rgExists = az group exists --name $resourceGroup 2>&1
if ($rgExists -eq 'false') {
    Write-Host "  Creating resource group: $resourceGroup" -ForegroundColor Yellow
    az group create --name $resourceGroup --location $location --output none
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Failed to create resource group" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ Resource group created" -ForegroundColor Green
} else {
    Write-Host "  ✓ Resource group exists" -ForegroundColor Green
}

# Check if storage account exists, create if not
$storageCheck = az storage account show --name $storageAccount --resource-group $resourceGroup 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creating storage account: $storageAccount" -ForegroundColor Yellow
    Write-Host "    This may take a minute..." -ForegroundColor Gray
    az storage account create --name $storageAccount --resource-group $resourceGroup --location $location --sku Standard_LRS --output none
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Failed to create storage account" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ Storage account created" -ForegroundColor Green
} else {
    Write-Host "  ✓ Storage account exists" -ForegroundColor Green
}

# Get storage account key
$storageKey = az storage account keys list --account-name $storageAccount --resource-group $resourceGroup --query "[0].value" --output tsv 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($storageKey)) {
    Write-Host "  ✗ Failed to retrieve storage key" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Storage key retrieved" -ForegroundColor Green

# Check if container exists, create if not
$containerCheck = az storage container exists --account-name $storageAccount --account-key $storageKey --name $container --output tsv 2>&1
if ($containerCheck -ne 'True') {
    Write-Host "  Creating container: $container" -ForegroundColor Yellow
    az storage container create --account-name $storageAccount --account-key $storageKey --name $container --output none
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Failed to create container" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ Container created" -ForegroundColor Green
} else {
    Write-Host "  ✓ Container exists" -ForegroundColor Green
}
Write-Host ""

# Determine next version number
Write-Host "Determining version..." -ForegroundColor Cyan
$blobList = az storage blob list --account-name $storageAccount --account-key $storageKey --container-name $container --output json 2>&1
$currentVersion = 0

if ($LASTEXITCODE -eq 0) {
    try {
        $blobs = $blobList | ConvertFrom-Json
        # Extract version numbers from blob names like "v1/retail/WTF/..."
        $versions = $blobs | ForEach-Object {
            if ($_.name -match '^v(\d+)/') { [int]$Matches[1] }
        } | Sort-Object -Unique
        if ($versions) {
            $currentVersion = ($versions | Measure-Object -Maximum).Maximum
        }
    } catch {
        Write-Verbose "  No existing blobs to parse"
    }
}

$nextVersion = $currentVersion + 1
Write-Host "  Current version: $(if ($currentVersion -eq 0) { 'none' } else { "v$currentVersion" })" -ForegroundColor Gray
Write-Host "  New version: v$nextVersion" -ForegroundColor Green
Write-Host ""

# Load WoW configuration
$newConfigScript = Join-Path $scriptsDir "New-WowConfig.ps1"
if (-not $config.installations) {
    Write-Host "No WoW installations configured. Running setup..." -ForegroundColor Cyan
    & $newConfigScript
    $config = & $configScript
    if (-not $config) {
        Write-Host "Error: Configuration creation failed." -ForegroundColor Red
        exit 1
    }
}

$wowRoot = $config.wowRoot
if (-not $wowRoot -or -not (Test-Path $wowRoot)) {
    Write-Host "Error: WoW root not found: $wowRoot" -ForegroundColor Red
    exit 1
}

$installCount = ($config.installations.PSObject.Properties | Measure-Object).Count
Write-Host "Uploading $installCount installation(s) as v$nextVersion..." -ForegroundColor Cyan
Write-Host ""

# Upload each installation
$totalFiles = 0

foreach ($installProp in $config.installations.PSObject.Properties) {
    $installKey = $installProp.Name
    $installInfo = $installProp.Value
    $installPath = Join-Path $wowRoot $installInfo.path
    $wtfPath = Join-Path $installPath "WTF"

    Write-Verbose "[$installKey] installPath: $installPath"
    Write-Verbose "[$installKey] wtfPath: $wtfPath"

    if (-not (Test-Path $installPath)) {
        Write-Host "  ⚠ Installation path not found: $installPath, skipping $installKey" -ForegroundColor Yellow
        continue
    }

    if (-not (Test-Path $wtfPath)) {
        Write-Host "  ⚠ WTF folder not found: $wtfPath, skipping $installKey" -ForegroundColor Yellow
        continue
    }

    Write-Host "Uploading: $installKey" -ForegroundColor Cyan

    # Remove addons with unsatisfiable dependencies before upload
    $addonReposPath = Join-Path $profileDir "addon-repos.json"
    if (Test-Path $addonReposPath) {
        $addonRepos = Get-Content $addonReposPath -Raw | ConvertFrom-Json
        $uninstallableSet = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]($addonRepos.addons.PSObject.Properties |
                Where-Object { -not $_.Value.github.owner -or -not $_.Value.github.repo } |
                ForEach-Object { $_.Name }),
            [System.StringComparer]::OrdinalIgnoreCase
        )

        $addonsDir = Join-Path $wowRoot $installInfo.path "Interface" "AddOns"
        if (Test-Path $addonsDir) {
            # Cascading removal of addons depending on uninstallable deps
            $removedAny = $true
            while ($removedAny) {
                $removedAny = $false
                foreach ($dir in @(Get-ChildItem -Path $addonsDir -Directory -ErrorAction SilentlyContinue)) {
                    $tocFile = Join-Path $dir.FullName "$($dir.Name).toc"
                    if (-not (Test-Path $tocFile)) { continue }
                    $depLine = Get-Content $tocFile -Encoding UTF8 -ErrorAction SilentlyContinue |
                        Where-Object { $_ -match '##\s*Dependencies\s*:\s*(.+)' }
                    if (-not $depLine) { continue }
                    if ($depLine -notmatch '##\s*Dependencies\s*:\s*(.+)') { continue }
                    $deps = $Matches[1] -split '\s*,\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    foreach ($dep in $deps) {
                        if ($uninstallableSet.Contains($dep)) {
                            Write-Host "  ✗ $($dir.Name) - depends on '$dep' (not installable), removing" -ForegroundColor Yellow
                            Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            $uninstallableSet.Add($dir.Name) | Out-Null
                            $removedAny = $true
                            break
                        }
                    }
                }
            }
        }
    }

    # Generate addons.json before upload
    $updateAddonsScript = Join-Path $scriptsDir "Update-AddonsJson.ps1"
    if (Test-Path $updateAddonsScript) {
        Write-Host "  Generating addons.json..." -ForegroundColor Gray
        try {
            $addonCount = & $updateAddonsScript -WowRoot $wowRoot -Installation $installInfo.path -InstallationKey $installKey
            Write-Host "  ✓ addons.json created with $addonCount addons" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠ Failed to generate addons.json: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Create temp directory for upload (excluding Config.wtf)
    $tempUploadDir = Join-Path $tempBase "wow-upload-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempUploadDir -Force | Out-Null

    try {
        $filesToCopy = Get-ChildItem -Path $wtfPath -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'Config.wtf' }

        foreach ($file in $filesToCopy) {
            $relativePath = $file.FullName.Replace($wtfPath, '').TrimStart([IO.Path]::DirectorySeparatorChar)
            $destFile = Join-Path $tempUploadDir $relativePath
            $destDir = Split-Path -Parent $destFile

            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $file.FullName -Destination $destFile -Force
        }

        $fileCount = (Get-ChildItem -Path $tempUploadDir -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count

        if ($fileCount -eq 0) {
            Write-Host "  ℹ No files to upload" -ForegroundColor Gray
            continue
        }

        Write-Host "  Uploading $fileCount files to v$nextVersion/$installKey/WTF..." -ForegroundColor Cyan

        $blobPrefix = "v$nextVersion/$installKey/WTF"
        Write-Verbose "  blob prefix: $blobPrefix"

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
Write-Host "Version: v$nextVersion" -ForegroundColor Cyan
Write-Host "Total files: $totalFiles" -ForegroundColor Cyan
Write-Host "Storage: $storageAccount/$container" -ForegroundColor Gray
Write-Host ""
Write-Host "To download this version: Wow-Download -Version $nextVersion" -ForegroundColor Gray
Write-Host ""
