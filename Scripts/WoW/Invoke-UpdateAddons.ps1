#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Check for and install updates for all managed WoW addons.

.DESCRIPTION
    Reads addon-repos.json, queries GitHub for the latest release of each addon,
    compares against the installed version, and re-installs any that are outdated.
    Updates installedVersion, latestVersion, and lastChecked in addon-repos.json.

.PARAMETER Installation
    WoW installation to update addons for (retail, classic, classicCata, beta, ptr, all)
    Default: retail

.PARAMETER Addon
    Check and update a specific addon by name.

.PARAMETER WhatIf
    Preview which addons would be updated without downloading.

.EXAMPLE
    Get-Updates

.EXAMPLE
    Get-Updates -Addon ConsolePort

.EXAMPLE
    Get-Updates -Installation all
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('retail', 'classic', 'classicCata', 'beta', 'ptr', 'all')]
    [string]$Installation = 'retail',

    [Parameter()]
    [string]$Addon,

    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WoW Addon Update Checker" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Verify gh CLI ─────────────────────────────────────────────────────────────

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Error: GitHub CLI (gh) not found" -ForegroundColor Red
    return
}

$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: GitHub CLI not authenticated. Run: gh auth login" -ForegroundColor Red
    return
}

# ── Load configuration ────────────────────────────────────────────────────────

$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$configScript = Join-Path $profileDir "Scripts" "WoW" "Get-WowConfig.ps1"

if (-not (Test-Path $configScript)) {
    Write-Host "Error: Run Setup.ps1 first." -ForegroundColor Red
    return
}

$addonReposPath = Join-Path $profileDir "addon-repos.json"
if (-not (Test-Path $addonReposPath)) {
    Write-Host "Error: addon-repos.json not found. Run Setup.ps1 first." -ForegroundColor Red
    return
}

$addonRepos = Get-Content $addonReposPath -Raw | ConvertFrom-Json

# ── Build addon list ──────────────────────────────────────────────────────────

$addonEntries = $addonRepos.addons.PSObject.Properties |
    Where-Object { $_.Value.github.owner -and $_.Value.github.repo }

if ($Addon) {
    $addonEntries = @($addonEntries | Where-Object { $_.Name -eq $Addon })
    if (-not $addonEntries) {
        Write-Host "Error: Addon '$Addon' not found in addon-repos.json" -ForegroundColor Red
        return
    }
}

$now = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
$toUpdate = [System.Collections.Generic.List[string]]::new()
$upToDate = 0
$noRelease = 0

# ── Check each addon for updates ──────────────────────────────────────────────

Write-Host "Checking for updates..." -ForegroundColor Cyan
Write-Host ""

foreach ($entry in $addonEntries) {
    $addonName = $entry.Name
    $addonInfo = $entry.Value
    $owner     = $addonInfo.github.owner
    $repo      = $addonInfo.github.repo

    # Skip addons with updateTracking disabled
    if ($addonInfo.updateTracking -and $addonInfo.updateTracking.enabled -eq $false) {
        Write-Host "  - $addonName (update tracking disabled)" -ForegroundColor DarkGray
        continue
    }

    $releaseJson = gh release view --repo "$owner/$repo" --json tagName 2>&1
    $addonInfo.updateTracking.lastChecked = $now

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ? $addonName - no releases on GitHub" -ForegroundColor DarkGray
        $noRelease++
        continue
    }

    $latestTag = ($releaseJson | ConvertFrom-Json).tagName
    $addonInfo.updateTracking.latestVersion = $latestTag

    $installedVersion = $addonInfo.updateTracking.installedVersion

    if ($installedVersion -and $installedVersion -eq $latestTag) {
        Write-Host "  ✓ $addonName - up to date ($latestTag)" -ForegroundColor Green
        $upToDate++
    } else {
        $fromStr = if ($installedVersion) { "$installedVersion → " } else { "" }
        Write-Host "  ↑ $addonName - update available ($fromStr$latestTag)" -ForegroundColor Yellow
        $toUpdate.Add($addonName)
    }
}

Write-Host ""
Write-Host "  $upToDate up to date, $($toUpdate.Count) to update, $noRelease with no releases" -ForegroundColor Cyan
Write-Host ""

# ── Save updated lastChecked / latestVersion back to addon-repos.json ─────────

$addonRepos.lastUpdated = $now
$addonRepos | ConvertTo-Json -Depth 10 | Set-Content -Path $addonReposPath -Encoding UTF8

# ── Install updates ───────────────────────────────────────────────────────────

if ($toUpdate.Count -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "All addons are up to date!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    return
}

if ($WhatIf) {
    Write-Host "[WhatIf] Would update: $($toUpdate -join ', ')" -ForegroundColor Yellow
    return
}

$getAddonsScript = Join-Path $profileDir "Scripts" "WoW" "Invoke-GetAddons.ps1"
if (-not (Test-Path $getAddonsScript)) {
    Write-Host "Error: Invoke-GetAddons.ps1 not found" -ForegroundColor Red
    return
}

foreach ($addonName in $toUpdate) {
    & $getAddonsScript -Installation $Installation -Addon $addonName -Force

    # Update installedVersion in addon-repos.json after successful install
    $addonRepos = Get-Content $addonReposPath -Raw | ConvertFrom-Json
    $entry = $addonRepos.addons.$addonName
    if ($entry -and $entry.updateTracking.latestVersion) {
        $entry.updateTracking.installedVersion = $entry.updateTracking.latestVersion
    }
    $addonRepos | ConvertTo-Json -Depth 10 | Set-Content -Path $addonReposPath -Encoding UTF8
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Updates Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
