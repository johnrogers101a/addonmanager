#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Loads and validates wow.json configuration.

.DESCRIPTION
    Reads wow.json from PowerShell profile directory and validates structure.
    Returns configuration object or throws error if invalid.

.OUTPUTS
    PSCustomObject - Configuration from wow.json

.EXAMPLE
    $config = & ".\Get-WowConfig.ps1"
    Write-Host "WoW Root: $($config.wowRoot)"
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    # Get profile directory
    $profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
    $configPath = Join-Path $profileDir "wow.json"
    
    if (-not (Test-Path $configPath)) {
        throw "wow.json not found at: $configPath`nRun New-WowConfig to create initial configuration."
    }
    
    # Load and parse configuration
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    
    # Validate required fields
    if (-not $config.wowRoot) {
        throw "Invalid wow.json: missing 'wowRoot' field"
    }
    
    if (-not $config.installations) {
        throw "Invalid wow.json: missing 'installations' field"
    }
    
    if (-not $config.azureSubscription) {
        throw "Invalid wow.json: missing 'azureSubscription' field"
    }
    
    if (-not $config.azureResourceGroup) {
        throw "Invalid wow.json: missing 'azureResourceGroup' field"
    }
    
    if (-not $config.azureStorageAccount) {
        throw "Invalid wow.json: missing 'azureStorageAccount' field"
    }
    
    if (-not $config.azureContainer) {
        throw "Invalid wow.json: missing 'azureContainer' field"
    }
    
    # Validate WoW root exists
    if (-not (Test-Path $config.wowRoot)) {
        throw "WoW root directory not found: $($config.wowRoot)"
    }
    
    return $config
}
catch {
    Write-Host "Error loading wow.json: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
