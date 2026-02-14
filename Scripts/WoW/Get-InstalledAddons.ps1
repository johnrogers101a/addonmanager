#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Scans Interface/AddOns folder and returns addon metadata.

.DESCRIPTION
    Scans specified WoW installation's Interface/AddOns folder.
    For each addon, parses .toc file and extracts metadata.
    Logs errors for failed parses but continues processing.

.PARAMETER WowRoot
    Root WoW directory

.PARAMETER Installation
    Installation folder name (e.g., "_retail_", "_classic_")

.OUTPUTS
    Array of PSCustomObject - Addon metadata

.EXAMPLE
    $addons = & ".\Get-InstalledAddons.ps1" -WowRoot "C:\...\World of Warcraft" -Installation "_retail_"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WowRoot,
    
    [Parameter(Mandatory = $true)]
    [string]$Installation
)

$ErrorActionPreference = 'Continue'

$addonsPath = Join-Path $WowRoot $Installation "Interface" "AddOns"
Write-Verbose "  AddOns path: $addonsPath"

if (-not (Test-Path $addonsPath)) {
    Write-Warning "AddOns folder not found: $addonsPath"
    return @()
}
Write-Verbose "  ✓ AddOns path exists"

$addonFolders = Get-ChildItem -Path $addonsPath -Directory -ErrorAction SilentlyContinue

if (-not $addonFolders) {
    Write-Verbose "No addons found in: $addonsPath"
    return @()
}

Write-Verbose "  Found $($addonFolders.Count) addon folders"

$addons = @()

# Resolve scripts directory from profile
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$scriptsDir = Join-Path $profileDir "Scripts/WoW"
$tocScript = Join-Path $scriptsDir "Get-TocMetadata.ps1"
Write-Verbose "  TOC script: $tocScript"

if (-not (Test-Path $tocScript)) {
    Write-Host "Error: Get-TocMetadata.ps1 not found at: $tocScript" -ForegroundColor Red
    return @()
}
Write-Verbose "  ✓ TOC script exists"

foreach ($folder in $addonFolders) {
    # Look for .toc file matching folder name
    $tocFile = Join-Path $folder.FullName "$($folder.Name).toc"
    
    if (-not (Test-Path $tocFile)) {
        Write-Verbose "TOC file not found for addon: $($folder.Name)"
        continue
    }
    
    try {
        $metadata = & $tocScript -TocPath $tocFile
        
        # Build addon object
        $addon = @{
            folder    = $folder.Name
            title     = $metadata.title
            version   = $metadata.version
            author    = $metadata.author
            notes     = $metadata.notes
            interface = $metadata.interface
        }
        
        $addons += [PSCustomObject]$addon
        Write-Verbose "Parsed addon: $($folder.Name)"
    }
    catch {
        Write-Host "  ⚠ Error parsing $($folder.Name).toc (skipped): $($_.Exception.Message)" -ForegroundColor Yellow
        continue
    }
}

return $addons
