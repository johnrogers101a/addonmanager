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
$WowScriptRoot = $PSScriptRoot

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
    $scriptPath = Join-Path $WowScriptRoot "Invoke-WowDownload.ps1"
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
    $scriptPath = Join-Path $WowScriptRoot "Invoke-WowUpload.ps1"
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
    $scriptPath = Join-Path $WowScriptRoot "New-WowConfig.ps1"
    & $scriptPath @args
}

function Get-WowConfig {
    <#
    .SYNOPSIS
        Display current wow.json settings.
    #>
    $scriptPath = Join-Path $WowScriptRoot "Get-WowConfig.ps1"
    & $scriptPath @args
}

function Get-WowInstallations {
    <#
    .SYNOPSIS
        List detected WoW installations.
    #>
    $scriptPath = Join-Path $WowScriptRoot "Get-WowInstallations.ps1"
    & $scriptPath @args
}

function Get-InstalledAddons {
    <#
    .SYNOPSIS
        List currently installed addons with metadata.
    .PARAMETER Installation
        WoW installation to scan (retail, classic, classicCata, beta, ptr)
    #>
    $scriptPath = Join-Path $WowScriptRoot "Get-InstalledAddons.ps1"
    & $scriptPath @args
}

function Update-AddonsJson {
    <#
    .SYNOPSIS
        Regenerate addons.json from Interface/AddOns folder.
    .PARAMETER Installation
        WoW installation to update (retail, classic, classicCata, beta, ptr)
    #>
    $scriptPath = Join-Path $WowScriptRoot "Update-AddonsJson.ps1"
    & $scriptPath @args
}

# Silent initialization - no output
# Commands will be shown by existing Show-Commands function


