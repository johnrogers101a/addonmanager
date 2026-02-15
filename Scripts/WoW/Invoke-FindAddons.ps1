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

# Run multiple searches from specific to broad, combine unique results
$allRepos = [ordered]@{}

# Phase 1: Search repos by keyword
$searches = @(
    "$Query topic:world-of-warcraft",
    "$Query topic:wow-addon",
    "$Query topic:wow",
    "$Query warcraft addon",
    "$Query wow addon",
    "$Query"
)

foreach ($searchQuery in $searches) {
    if ($allRepos.Count -ge $Limit) { break }
    $remaining = $Limit - $allRepos.Count
    $results = gh search repos $searchQuery --limit $remaining --json fullName,description,stargazersCount,updatedAt,url 2>&1
    if ($LASTEXITCODE -eq 0 -and $results) {
        try {
            $parsed = $results | ConvertFrom-Json
            foreach ($r in $parsed) {
                if (-not $allRepos.ContainsKey($r.fullName)) {
                    $allRepos[$r.fullName] = $r
                }
            }
        } catch {}
    }
}

# Phase 2: Search as GitHub user/org — list their repos and find WoW addons
if ($allRepos.Count -lt $Limit) {
    Write-Host "Checking if '$Query' is a GitHub user..." -ForegroundColor Gray
    $userRepos = gh repo list $Query --limit 50 --json name,description,url 2>&1
    if ($LASTEXITCODE -eq 0 -and $userRepos) {
        try {
            $parsed = $userRepos | ConvertFrom-Json
            foreach ($r in $parsed) {
                if ($allRepos.Count -ge $Limit) { break }
                $fullName = "$Query/$($r.name)"
                if ($allRepos.ContainsKey($fullName)) { continue }

                # Validate it's a WoW addon by checking for .toc files
                Write-Verbose "  Checking $fullName for .toc files..."
                $tocCheck = gh api "repos/$fullName/git/trees/HEAD?recursive=1" --jq '.tree[].path' 2>&1
                if ($LASTEXITCODE -ne 0) { continue }

                $hasToc = $tocCheck | Where-Object { $_ -match '\.toc$' } | Select-Object -First 1
                if (-not $hasToc) { continue }

                # It's a WoW addon — get full repo info
                $repoInfo = gh repo view $fullName --json fullName,description,stargazersCount,updatedAt,url 2>&1
                if ($LASTEXITCODE -eq 0) {
                    try {
                        $repoData = $repoInfo | ConvertFrom-Json
                        $allRepos[$repoData.fullName] = $repoData
                        Write-Verbose "  ✓ $fullName is a WoW addon"
                    } catch {}
                }
            }
        } catch {}
    }
}

$repos = @($allRepos.Values)

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
