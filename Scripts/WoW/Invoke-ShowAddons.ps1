#!/usr/bin/env pwsh
<#
.SYNOPSIS
    List currently installed WoW addons.

.DESCRIPTION
    Scans the Interface/AddOns folder for each WoW installation and
    displays installed addons with metadata from their .toc files.

.EXAMPLE
    Show-Addons

.NOTES
    Requires wow.json configuration (run Setup.ps1 first).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Load wow.json
$profileDir = if ($IsWindows -or $env:OS -match 'Windows') {
    Join-Path $HOME "Documents" "PowerShell"
} else {
    Join-Path $HOME ".config" "powershell"
}
$configPath = Join-Path $profileDir "wow.json"

if (-not (Test-Path $configPath)) {
    Write-Host "Error: wow.json not found. Run Setup.ps1 first." -ForegroundColor Red
    return
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$wowRoot = $config.wowRoot

if (-not (Test-Path $wowRoot)) {
    Write-Host "Error: WoW root not found: $wowRoot" -ForegroundColor Red
    return
}

# Load addon-repos.json to show GitHub source info
$addonReposPath = Join-Path $profileDir "addon-repos.json"
$addonRepos = $null
if (Test-Path $addonReposPath) {
    $addonRepos = (Get-Content $addonReposPath -Raw | ConvertFrom-Json).addons
}

$scriptsDir = Join-Path $profileDir "Scripts" "WoW"
$getInstalledScript = Join-Path $scriptsDir "Get-InstalledAddons.ps1"

if (-not (Test-Path $getInstalledScript)) {
    Write-Host "Error: Get-InstalledAddons.ps1 not found" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installed WoW Addons" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($installKey in $config.installations.PSObject.Properties.Name) {
    $install = $config.installations.$installKey
    $installPath = $install.path
    $installDesc = $install.description

    Write-Host "$installDesc ($installPath)" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor DarkGray

    $addons = & $getInstalledScript -WowRoot $wowRoot -Installation $installPath

    if (-not $addons -or $addons.Count -eq 0) {
        Write-Host "  No addons installed" -ForegroundColor Gray
        Write-Host ""
        continue
    }

    # Sort by folder name
    $addons = $addons | Sort-Object folder

    $index = 0
    foreach ($addon in $addons) {
        $index++
        $name = if ($addon.title) { $addon.title } else { $addon.folder }
        $version = if ($addon.version) {
            $v = $addon.version
            if ($v -match '^v') { " $v" } else { " v$v" }
        } else { "" }
        $author = if ($addon.author) { " by $($addon.author)" } else { "" }

        # Check if this addon has a GitHub source in addon-repos.json
        $source = ""
        if ($addonRepos) {
            $repoEntry = $addonRepos.PSObject.Properties | Where-Object {
                $_.Name -eq $addon.folder -or
                ($_.Value.github.repo -and $_.Value.github.repo -eq $addon.folder)
            } | Select-Object -First 1
            if ($repoEntry -and $repoEntry.Value.github.owner -and $repoEntry.Value.github.repo) {
                $source = " [$($repoEntry.Value.github.owner)/$($repoEntry.Value.github.repo)]"
            }
        }

        Write-Host "  $index. " -NoNewline -ForegroundColor DarkGray
        Write-Host "$name" -NoNewline -ForegroundColor White
        Write-Host "$version" -NoNewline -ForegroundColor DarkCyan
        Write-Host "$author" -NoNewline -ForegroundColor DarkGray
        if ($source) { Write-Host "$source" -NoNewline -ForegroundColor DarkYellow }
        Write-Host ""

        if ($addon.notes) {
            Write-Host "     $($addon.notes)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "  Total: $($addons.Count) addons" -ForegroundColor Cyan
    Write-Host ""
}
