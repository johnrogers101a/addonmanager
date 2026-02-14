#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates or updates addons.json file with current addon inventory.

.DESCRIPTION
    Scans Interface/AddOns folder and creates addons.json in WTF folder.
    Parses .toc files for metadata.
    Logs errors for failed parses but continues.

.PARAMETER WowRoot
    Root WoW directory

.PARAMETER Installation
    Installation folder name (e.g., "_retail_", "_classic_")

.PARAMETER InstallationKey
    Installation key for JSON (e.g., "retail", "classic")

.OUTPUTS
    None - Creates/updates addons.json file

.EXAMPLE
    & ".\Update-AddonsJson.ps1" -WowRoot "C:\...\World of Warcraft" -Installation "_retail_" -InstallationKey "retail"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WowRoot,
    
    [Parameter(Mandatory = $true)]
    [string]$Installation,
    
    [Parameter(Mandatory = $true)]
    [string]$InstallationKey
)

$ErrorActionPreference = 'Stop'

Write-Verbose "Generating addon inventory for $InstallationKey..."

# Resolve scripts directory from profile
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$scriptsDir = Join-Path $profileDir "Scripts/WoW"
Write-Verbose "  Scripts directory: $scriptsDir"

$getAddonsScript = Join-Path $scriptsDir "Get-InstalledAddons.ps1"
Write-Verbose "  Get-InstalledAddons script: $getAddonsScript"

if (-not (Test-Path $getAddonsScript)) {
    Write-Host "Error: Get-InstalledAddons.ps1 not found at: $getAddonsScript" -ForegroundColor Red
    return 0
}
Write-Verbose "  ✓ exists"

$addons = & $getAddonsScript -WowRoot $WowRoot -Installation $Installation

# Build addons.json content
$addonsJson = @{
    generatedAt  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    installation = $InstallationKey
    addons       = $addons
}

# Save to WTF folder
$wtfPath = Join-Path $WowRoot $Installation "WTF"
Write-Verbose "  WTF path for addons.json: $wtfPath"

if (-not (Test-Path $wtfPath)) {
    Write-Host "Error: WTF folder not found: $wtfPath" -ForegroundColor Red
    return 0
}
Write-Verbose "  ✓ exists"

$jsonPath = Join-Path $wtfPath "addons.json"
Write-Verbose "  addons.json path: $jsonPath"

$addonsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Verbose "  ✓ Created addons.json with $($addons.Count) addons at: $jsonPath"

return $addons.Count
