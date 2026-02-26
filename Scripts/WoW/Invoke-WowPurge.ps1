#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deletes the WoW Azure storage account so the next upload starts fresh.

.DESCRIPTION
    Purges all versioned WoW configuration data from Azure by deleting the
    storage account. The next Wow-Upload will recreate it and start at v1.
    Prompts for confirmation before deleting.

.PARAMETER Force
    Skip confirmation prompt.

.EXAMPLE
    Invoke-WowPurge
    Prompts for confirmation then deletes the storage account.

.EXAMPLE
    Wow-Purge -Force
    Deletes without prompting.

.NOTES
    Requires Azure CLI and authentication.
    Storage account and subscription are read from wow.json.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "WoW Storage Purge" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

# Resolve profile directory
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$scriptsDir = Join-Path $profileDir "Scripts" "WoW"

if (-not (Test-Path $scriptsDir)) {
    Write-Host "Error: Scripts directory not found: $scriptsDir" -ForegroundColor Red
    Write-Host "Run Setup.ps1 from the addonmanager repository." -ForegroundColor Yellow
    return
}

# Load configuration
$configScript = Join-Path $scriptsDir "Get-WowConfig.ps1"
if (-not (Test-Path $configScript)) {
    Write-Host "Error: Get-WowConfig.ps1 not found" -ForegroundColor Red
    return
}

$config = & $configScript
if (-not $config) {
    Write-Host "Error: Failed to load wow.json. Run Setup.ps1 first." -ForegroundColor Red
    return
}

$subscription = $config.azureSubscription
$resourceGroup = $config.azureResourceGroup
$storageAccount = $config.azureStorageAccount

# Verify Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Azure CLI not found" -ForegroundColor Red
    return
}

# Verify logged in
Write-Host "Verifying Azure authentication..." -ForegroundColor Cyan
$azAccount = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Not logged into Azure" -ForegroundColor Red
    Write-Host "  Run: az login" -ForegroundColor White
    return
}

az account set --subscription $subscription 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Failed to set subscription: $subscription" -ForegroundColor Red
    return
}
Write-Host "  ✓ Authenticated: $subscription" -ForegroundColor Green
Write-Host ""

# Check if storage account exists
$storageCheck = az storage account show --name $storageAccount --resource-group $resourceGroup 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Storage account '$storageAccount' does not exist. Nothing to purge." -ForegroundColor Yellow
    return
}

# List versions for context
$storageKey = az storage account keys list --account-name $storageAccount --resource-group $resourceGroup --query "[0].value" --output tsv 2>&1
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($storageKey)) {
    $blobList = az storage blob list --account-name $storageAccount --account-key $storageKey --container-name $config.azureContainer --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        try {
            $blobs = $blobList | ConvertFrom-Json
            $versions = $blobs | ForEach-Object {
                if ($_.name -match '^v(\d+)/') { [int]$Matches[1] }
            } | Sort-Object -Unique
            $totalBlobs = $blobs.Count
            if ($versions) {
                Write-Host "Storage account: $storageAccount" -ForegroundColor Cyan
                Write-Host "Versions: $(($versions | ForEach-Object { "v$_" }) -join ', ')" -ForegroundColor Cyan
                Write-Host "Total blobs: $totalBlobs" -ForegroundColor Cyan
            }
        } catch {}
    }
}

Write-Host ""
Write-Host "⚠ This will permanently delete storage account '$storageAccount'" -ForegroundColor Red
Write-Host "  All versions and WTF configuration data will be lost." -ForegroundColor Red
Write-Host "  The next Wow-Upload will create a new storage account starting at v1." -ForegroundColor Gray
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Type 'DELETE' to confirm"
    if ($confirm -ne 'DELETE') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }
    Write-Host ""
}

# Delete storage account
Write-Host "Deleting storage account '$storageAccount'..." -ForegroundColor Cyan
az storage account delete --name $storageAccount --resource-group $resourceGroup --yes --output none
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Failed to delete storage account" -ForegroundColor Red
    return
}

Write-Host "  ✓ Storage account deleted" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Purge Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Run Wow-Upload to create a fresh storage account starting at v1." -ForegroundColor Gray
Write-Host ""
