#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Remove a WoW addon and upload changes to Azure.

.DESCRIPTION
    Removes an addon from the specified WoW installation:
    1. Searches for addon folders matching the name
    2. Removes all matching folders from Interface/AddOns
    3. Removes entry from addon-repos.json if present
    4. Uploads changes to Azure via Wow-Upload

.PARAMETER Name
    Addon name or partial name to remove (case-insensitive)

.PARAMETER Installation
    WoW installation to remove from (default: retail)

.PARAMETER SkipUpload
    Don't upload to Azure after removal

.PARAMETER WhatIf
    Preview changes without removing

.EXAMPLE
    Remove-Addon BugSack
    Remove BugSack addon from retail and upload

.EXAMPLE
    Remove-Addon "Btw" -SkipUpload
    Remove all addons starting with "Btw" without uploading

.EXAMPLE
    Remove-Addon DBM -Installation classic
    Remove DBM from classic installation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,

    [Parameter(Position = 1)]
    [ValidateSet('retail', 'classic', 'classicCata', 'beta', 'ptr')]
    [string]$Installation = 'retail',

    [Parameter()]
    [switch]$SkipUpload,

    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Remove Addon: $Name" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$configScript = Join-Path $profileDir "Scripts" "WoW" "Get-WowConfig.ps1"

if (-not (Test-Path $configScript)) {
    Write-Host "Error: Get-WowConfig.ps1 not found" -ForegroundColor Red
    return
}

try {
    $config = & $configScript
    Write-Host "✓ Configuration loaded" -ForegroundColor Green
}
catch {
    Write-Host "Error loading configuration: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Map installation name to folder
$installationMap = @{
    'retail' = '_retail_'
    'classic' = '_classic_era_'
    'classicCata' = '_classic_'
    'beta' = '_beta_'
    'ptr' = '_ptr_'
}

$installFolder = $installationMap[$Installation]
if (-not $installFolder) {
    Write-Host "Error: Invalid installation: $Installation" -ForegroundColor Red
    return
}

$addonsPath = Join-Path $config.wowRoot $installFolder "Interface" "AddOns"

if (-not (Test-Path $addonsPath)) {
    Write-Host "Error: AddOns folder not found: $addonsPath" -ForegroundColor Red
    return
}

Write-Host "Installation: $Installation" -ForegroundColor Cyan
Write-Host "AddOns Path: $addonsPath" -ForegroundColor Gray
Write-Host ""

# Find matching addon folders
Write-Host "Searching for addon folders matching '$Name'..." -ForegroundColor Cyan
$matchingFolders = Get-ChildItem -Path $addonsPath -Directory | 
    Where-Object { $_.Name -like "*$Name*" }

if (-not $matchingFolders) {
    Write-Host "  ✗ No addons found matching '$Name'" -ForegroundColor Red
    return
}

Write-Host "  Found $($matchingFolders.Count) addon folder(s):" -ForegroundColor Yellow
foreach ($folder in $matchingFolders) {
    Write-Host "    - $($folder.Name)" -ForegroundColor White
}
Write-Host ""

if ($WhatIf) {
    Write-Host "WhatIf: Would remove $($matchingFolders.Count) addon folder(s)" -ForegroundColor Yellow
    if (-not $SkipUpload) {
        Write-Host "WhatIf: Would upload changes to Azure" -ForegroundColor Yellow
    }
    return
}

# Confirm deletion
$confirmation = Read-Host "Remove these $($matchingFolders.Count) addon folder(s)? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Cancelled" -ForegroundColor Yellow
    return
}

# Remove addon folders
Write-Host ""
Write-Host "Removing addon folders..." -ForegroundColor Cyan
foreach ($folder in $matchingFolders) {
    try {
        Remove-Item -Path $folder.FullName -Recurse -Force
        Write-Host "  ✓ Removed: $($folder.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to remove $($folder.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Remove from addon-repos.json if present
$addonReposPath = Join-Path $profileDir "addon-repos.json"
if (Test-Path $addonReposPath) {
    try {
        $addonRepos = Get-Content $addonReposPath -Raw | ConvertFrom-Json
        $originalCount = $addonRepos.Count
        
        # Remove entries where the name matches any of the removed folders
        $folderNames = $matchingFolders | ForEach-Object { $_.Name }
        $addonRepos = $addonRepos | Where-Object { 
            $addonName = if ($_.name) { $_.name } else { ($_.repo -split '/')[-1] }
            $folderNames -notcontains $addonName
        }
        
        if ($addonRepos.Count -lt $originalCount) {
            $addonRepos | ConvertTo-Json -Depth 10 | Set-Content $addonReposPath -Encoding UTF8
            Write-Host "  ✓ Updated addon-repos.json (removed $($originalCount - $addonRepos.Count) entry/entries)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ⚠ Failed to update addon-repos.json: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Removal Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Upload to Azure
if (-not $SkipUpload) {
    Write-Host "Uploading changes to Azure..." -ForegroundColor Cyan
    Write-Host ""
    
    $uploadScript = Join-Path $profileDir "Scripts" "WoW" "Invoke-WowUpload.ps1"
    if (Test-Path $uploadScript) {
        & $uploadScript
    }
    else {
        Write-Host "  ⚠ Wow-Upload script not found, skipping upload" -ForegroundColor Yellow
        Write-Host "  Run 'Wow-Upload' manually to sync changes" -ForegroundColor Gray
    }
}
else {
    Write-Host "Skipped upload (use -SkipUpload to prevent auto-upload)" -ForegroundColor Gray
    Write-Host "Run 'Wow-Upload' to sync changes to Azure" -ForegroundColor Cyan
}

Write-Host ""
