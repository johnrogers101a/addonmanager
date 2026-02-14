#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Discovers and validates WoW installation paths.

.DESCRIPTION
    Scans WoW root directory for valid installations (_retail_, _classic_, etc.).
    Returns list of detected installations with paths and descriptions.

.PARAMETER WowRoot
    Root WoW directory to scan (e.g., "C:\Program Files (x86)\World of Warcraft")

.OUTPUTS
    Array of PSCustomObject - Detected installations

.EXAMPLE
    $installations = & ".\Get-WowInstallations.ps1" -WowRoot "C:\Program Files (x86)\World of Warcraft"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WowRoot
)

$ErrorActionPreference = 'Stop'

# Known WoW installation folder patterns
$knownInstallations = @{
    '_retail_'      = 'World of Warcraft Retail'
    '_classic_era_' = 'World of Warcraft Classic Era'
    '_classic_'     = 'World of Warcraft Classic Cataclysm'
    '_beta_'        = 'World of Warcraft Beta'
    '_ptr_'         = 'World of Warcraft PTR'
}

$detectedInstallations = @{}

foreach ($folder in $knownInstallations.Keys) {
    $fullPath = Join-Path $WowRoot $folder
    
    if (Test-Path $fullPath) {
        # Verify it has Interface and WTF folders
        $interfacePath = Join-Path $fullPath "Interface"
        $wtfPath = Join-Path $fullPath "WTF"
        
        if ((Test-Path $interfacePath) -and (Test-Path $wtfPath)) {
            # Determine key name (remove underscores)
            $key = switch ($folder) {
                '_retail_'      { 'retail' }
                '_classic_era_' { 'classic' }
                '_classic_'     { 'classicCata' }
                '_beta_'        { 'beta' }
                '_ptr_'         { 'ptr' }
            }
            
            $detectedInstallations[$key] = @{
                path        = $folder
                description = $knownInstallations[$folder]
            }
            
            Write-Verbose "Detected: $key at $fullPath"
        }
    }
}

if ($detectedInstallations.Count -eq 0) {
    Write-Warning "No WoW installations detected in: $WowRoot"
}

return $detectedInstallations
