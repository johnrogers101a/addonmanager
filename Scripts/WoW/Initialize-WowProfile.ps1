#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initializes WoW management functions in PowerShell profile.

.DESCRIPTION
    Defines wrapper functions for WoW addon and configuration management.
    Functions call corresponding scripts in the same directory.
    Pattern follows powershell-config Initialize-PowerShellProfile.ps1.
    
    Silent initialization - does not print output (integrated with Show-Commands).

.EXAMPLE
    . "C:\Path\To\Scripts\WoW\Initialize-WowProfile.ps1"
    Loads WoW management functions into current session.

.OUTPUTS
    None (defines functions in session scope)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Get script directory for function calls
# When dot-sourced, $PSScriptRoot is unreliable, so compute from profile directory
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$script:WowScriptRoot = Join-Path $profileDir "Scripts/WoW"

# Validate script directory exists
if (-not (Test-Path $script:WowScriptRoot)) {
    Write-Host "Error: WoW scripts directory not found: $script:WowScriptRoot" -ForegroundColor Red
    Write-Host "Please run Setup.ps1 from the addonmanager repository." -ForegroundColor Yellow
    return
}

# Primary WoW Management Functions
function Invoke-WowDownload {
    <#
    .SYNOPSIS
        Download and sync WTF configuration from Azure Blob Storage.
    .PARAMETER Installation
        WoW installation to sync (retail, classic, classicCata, beta, ptr, all)
    .PARAMETER WhatIf
        Preview changes without applying
    #>
    $scriptPath = Join-Path $script:WowScriptRoot "Invoke-WowDownload.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script not found: $scriptPath" -ForegroundColor Red
        return
    }
    & $scriptPath @args
}

function Invoke-WowUpload {
    <#
    .SYNOPSIS
        Upload WTF configuration to Azure Blob Storage.
    .DESCRIPTION
        Uploads all WTF configurations from repository to Azure.
        Creates Azure resources if they don't exist (idempotent).
    #>
    $scriptPath = Join-Path $script:WowScriptRoot "Invoke-WowUpload.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script not found: $scriptPath" -ForegroundColor Red
        return
    }
    & $scriptPath @args
}

# Aliases for convenience
Set-Alias -Name Wow-Download -Value Invoke-WowDownload
Set-Alias -Name Wow-Upload -Value Invoke-WowUpload

# Helper Functions
function New-WowConfig {
    <#
    .SYNOPSIS
        Create initial wow.json configuration file.
    .DESCRIPTION
        Interactive wizard that detects WoW installations and creates wow.json.
    #>
    $scriptPath = Join-Path $script:WowScriptRoot "New-WowConfig.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script not found: $scriptPath" -ForegroundColor Red
        return
    }
    & $scriptPath @args
}

function Get-WowConfig {
    <#
    .SYNOPSIS
        Display current wow.json settings.
    #>
    $scriptPath = Join-Path $script:WowScriptRoot "Get-WowConfig.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script not found: $scriptPath" -ForegroundColor Red
        return
    }
    & $scriptPath @args
}

function Get-WowInstallations {
    <#
    .SYNOPSIS
        List detected WoW installations.
    #>
    $scriptPath = Join-Path $script:WowScriptRoot "Get-WowInstallations.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script not found: $scriptPath" -ForegroundColor Red
        return
    }
    & $scriptPath @args
}

function Get-InstalledAddons {
    <#
    .SYNOPSIS
        List currently installed addons with metadata.
    .PARAMETER Installation
        WoW installation to scan (retail, classic, classicCata, beta, ptr)
    #>
    $scriptPath = Join-Path $script:WowScriptRoot "Get-InstalledAddons.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script not found: $scriptPath" -ForegroundColor Red
        return
    }
    & $scriptPath @args
}

function Update-AddonsJson {
    <#
    .SYNOPSIS
        Regenerate addons.json from Interface/AddOns folder.
    .PARAMETER Installation
        WoW installation to update (retail, classic, classicCata, beta, ptr)
    #>
    $scriptPath = Join-Path $script:WowScriptRoot "Update-AddonsJson.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script not found: $scriptPath" -ForegroundColor Red
        return
    }
    & $scriptPath @args
}

# Append WoW commands to the display (Initialize-PowerShellProfile already started the output)
Write-Host "  Wow-Download              " -NoNewline -ForegroundColor Green
Write-Host "- Sync WTF configuration from Azure" -ForegroundColor Gray
Write-Host "  Wow-Upload                " -NoNewline -ForegroundColor Green
Write-Host "- Upload WTF configuration to Azure" -ForegroundColor Gray
Write-Host ""


