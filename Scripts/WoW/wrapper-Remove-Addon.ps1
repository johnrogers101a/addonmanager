#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Remove a WoW addon and upload changes to Azure

.DESCRIPTION
    Remove a WoW addon and upload changes to Azure
#>
param()
$wowScript = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-RemoveAddon.ps1"
& $wowScript @args
