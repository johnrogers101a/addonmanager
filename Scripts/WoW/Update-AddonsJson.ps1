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

# Get installed addons
$getAddonsScript = Join-Path $PSScriptRoot "Get-InstalledAddons.ps1"
$addons = & $getAddonsScript -WowRoot $WowRoot -Installation $Installation

# Build addons.json content
$addonsJson = @{
    generatedAt  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    installation = $InstallationKey
    addons       = $addons
}

# Save to WTF folder
$wtfPath = Join-Path $WowRoot $Installation "WTF"
$jsonPath = Join-Path $wtfPath "addons.json"

$addonsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Verbose "Created addons.json with $($addons.Count) addons at: $jsonPath"

return $addons.Count
