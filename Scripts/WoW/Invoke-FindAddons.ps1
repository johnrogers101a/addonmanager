#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Search GitHub for WoW addons.

.DESCRIPTION
    Searches GitHub repositories for World of Warcraft addons using the
    GitHub CLI. Returns matching repos with descriptions and release info.

.PARAMETER Query
    Search terms (e.g. "damage meter", "quest tracker", "unit frames")

.PARAMETER Limit
    Maximum results to return (default: 10)

.EXAMPLE
    Find-Addons "damage meter"

.EXAMPLE
    Find-Addons "quest tracker" -Limit 20

.NOTES
    Requires GitHub CLI (gh) and authentication.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query,

    [Parameter()]
    [int]$Limit = 10
)

$ErrorActionPreference = 'Stop'

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
Write-Host "Searching GitHub for WoW addons: '$Query'..." -ForegroundColor Cyan
Write-Host ""

# Search GitHub for WoW-related repos matching the query
$searchQuery = "$Query world of warcraft addon"
$results = gh search repos $searchQuery --limit $Limit --json fullName,description,stargazersCount,updatedAt,url 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Search failed" -ForegroundColor Red
    Write-Host $results -ForegroundColor Gray
    return
}

$repos = $results | ConvertFrom-Json

if (-not $repos -or $repos.Count -eq 0) {
    # Try broader search without "addon"
    $searchQuery = "$Query warcraft"
    $results = gh search repos $searchQuery --limit $Limit --json fullName,description,stargazersCount,updatedAt,url 2>&1
    if ($LASTEXITCODE -eq 0) {
        $repos = $results | ConvertFrom-Json
    }
}

if (-not $repos -or $repos.Count -eq 0) {
    Write-Host "No results found for '$Query'" -ForegroundColor Yellow
    return
}

# Load addon-repos.json to mark already-installed addons
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$addonReposPath = Join-Path $profileDir "addon-repos.json"
$installedRepos = @{}
if (Test-Path $addonReposPath) {
    $addonRepos = Get-Content $addonReposPath -Raw | ConvertFrom-Json
    foreach ($prop in $addonRepos.addons.PSObject.Properties) {
        $info = $prop.Value
        if ($info.github.owner -and $info.github.repo) {
            $key = "$($info.github.owner)/$($info.github.repo)".ToLower()
            $installedRepos[$key] = $prop.Name
        }
    }
}

Write-Host "Results:" -ForegroundColor Cyan
Write-Host ""

$index = 0
foreach ($repo in $repos) {
    $index++
    $fullName = $repo.fullName
    $desc = if ($repo.description) { $repo.description } else { "(no description)" }
    $stars = $repo.stargazersCount
    $updated = if ($repo.updatedAt) { ([datetime]$repo.updatedAt).ToString("yyyy-MM-dd") } else { "unknown" }

    $installedAs = $installedRepos[$fullName.ToLower()]
    $statusTag = if ($installedAs) { " [INSTALLED as $installedAs]" } else { "" }
    $color = if ($installedAs) { "Gray" } else { "White" }

    Write-Host "  $index. " -NoNewline -ForegroundColor Yellow
    Write-Host "$fullName" -NoNewline -ForegroundColor $color
    if ($installedAs) { Write-Host $statusTag -NoNewline -ForegroundColor Green }
    Write-Host " (★$stars, updated $updated)" -ForegroundColor DarkGray
    Write-Host "     $desc" -ForegroundColor Gray
    Write-Host "     Install: " -NoNewline -ForegroundColor DarkGray
    Write-Host "Install-Addon $fullName" -ForegroundColor Cyan
    Write-Host ""
}
