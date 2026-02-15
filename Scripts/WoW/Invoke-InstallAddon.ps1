#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install a new WoW addon from GitHub.

.DESCRIPTION
    Adds a new addon to addon-repos.json and installs it from GitHub.
    Accepts a GitHub repo in owner/repo format. Fetches repo metadata,
    determines the addon folder name, downloads the latest release
    (or clones if no release), and installs to Interface/AddOns.

.PARAMETER Repo
    GitHub repository in owner/repo format (e.g. "funkydude/BugSack")

.PARAMETER Name
    Override the addon folder name. By default, uses the repo name.

.PARAMETER Branch
    Git branch to use for clone fallback (default: auto-detect)

.PARAMETER Installation
    WoW installation to install to (default: retail)

.PARAMETER WhatIf
    Preview without installing.

.EXAMPLE
    Install-Addon funkydude/BugSack

.EXAMPLE
    Install-Addon Breeni/BtWQuestsDragonflight -Branch mainline

.NOTES
    Requires GitHub CLI (gh) and authentication.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Repo,

    [Parameter()]
    [string]$Name,

    [Parameter()]
    [string]$Branch,

    [Parameter()]
    [ValidateSet('retail', 'classic', 'classicCata', 'beta', 'ptr')]
    [string]$Installation = 'retail',

    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Validate repo format
if ($Repo -notmatch '^[\w\-\.]+/[\w\-\.]+$') {
    Write-Host "Error: Invalid repo format. Use owner/repo (e.g. funkydude/BugSack)" -ForegroundColor Red
    return
}

$owner, $repoName = $Repo -split '/', 2

# Verify gh CLI
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Error: GitHub CLI (gh) not found" -ForegroundColor Red
    return
}

$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: GitHub CLI not authenticated. Run: gh auth login" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Install Addon: $Repo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Fetch repo info
Write-Host "Fetching repository info..." -ForegroundColor Cyan
$repoInfo = gh repo view $Repo --json name,description,defaultBranchRef 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Repository not found: $Repo" -ForegroundColor Red
    return
}

$repoData = $repoInfo | ConvertFrom-Json
$addonName = if ($Name) { $Name } else { $repoData.name }
$description = if ($repoData.description) { $repoData.description } else { "" }
$defaultBranch = if ($Branch) { $Branch } else { $repoData.defaultBranchRef.name }

Write-Host "  Name: $addonName" -ForegroundColor Green
Write-Host "  Description: $description" -ForegroundColor Gray
Write-Host "  Branch: $defaultBranch" -ForegroundColor Gray
Write-Host ""

# Load config
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$configScript = Join-Path $profileDir "Scripts" "WoW" "Get-WowConfig.ps1"
if (-not (Test-Path $configScript)) {
    Write-Host "Error: Run Setup.ps1 first." -ForegroundColor Red
    return
}
$config = & $configScript

# Check if already in addon-repos.json
$addonReposPath = Join-Path $profileDir "addon-repos.json"
if (-not (Test-Path $addonReposPath)) {
    Write-Host "Error: addon-repos.json not found. Run Setup.ps1 first." -ForegroundColor Red
    return
}

$addonRepos = Get-Content $addonReposPath -Raw | ConvertFrom-Json
$existing = $addonRepos.addons.PSObject.Properties | Where-Object {
    $_.Value.github.owner -eq $owner -and $_.Value.github.repo -eq $repoName
}

if ($existing) {
    Write-Host "  ℹ Already in addon-repos.json as '$($existing.Name)'" -ForegroundColor Yellow
    Write-Host "  Use Get-Addons -Addon $($existing.Name) -Force to reinstall" -ForegroundColor Gray
    return
}

if ($WhatIf) {
    Write-Host "[WhatIf] Would add $addonName to addon-repos.json and install from $Repo" -ForegroundColor Yellow
    return
}

# Add to addon-repos.json
Write-Host "Adding to addon-repos.json..." -ForegroundColor Cyan

$newEntry = [PSCustomObject]@{
    github = [PSCustomObject]@{
        owner  = $owner
        repo   = $repoName
        branch = $defaultBranch
    }
    metadata = [PSCustomObject]@{
        author      = $owner
        description = $description
        curseforgeId = $null
    }
    updateTracking = [PSCustomObject]@{
        enabled          = $true
        checkReleases    = $true
        lastChecked      = $null
        installedVersion = $null
        latestVersion    = $null
    }
    download = [PSCustomObject]@{
        assetPattern    = "*.zip"
        excludePatterns = @()
        installPath     = $addonName
    }
}

$addonRepos.addons | Add-Member -NotePropertyName $addonName -NotePropertyValue $newEntry -Force
$addonRepos.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
$addonRepos | ConvertTo-Json -Depth 10 | Set-Content -Path $addonReposPath -Encoding UTF8
Write-Host "  ✓ Added $addonName" -ForegroundColor Green
Write-Host ""

# Install the addon using Get-Addons
Write-Host "Installing $addonName..." -ForegroundColor Cyan
$getAddonsScript = Join-Path $profileDir "Scripts" "WoW" "Invoke-GetAddons.ps1"
if (Test-Path $getAddonsScript) {
    & $getAddonsScript -Installation $Installation -Addon $addonName -Force
} else {
    Write-Host "  ✗ Invoke-GetAddons.ps1 not found" -ForegroundColor Red
}
