#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Search GitHub for WoW addons.

.DESCRIPTION
    Searches GitHub repositories for World of Warcraft addons using the
    GitHub CLI. Uses progressive search: repo name, then owner/user lookup.
    Validates results by checking for .toc files with retail Interface versions.

.PARAMETER Query
    Search terms (e.g. "damage meter", "DanderBot", "bugsack")

.PARAMETER Limit
    Maximum results to return (default: 10)

.EXAMPLE
    Find-Addons "damage meter"

.EXAMPLE
    Find-Addons "DanderBot"

.EXAMPLE
    Find-Addons "bugsack" -Limit 20

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

# Collect unique candidates keyed by fullName
$candidates = @{}
$searchLimit = [Math]::Max($Limit * 3, 30) # fetch extra since we'll filter

# Build search queries: repo name first, then owner, then broader
$searches = @(
    @{ Args = $Query; Label = "Searching repos for '$Query'" }
)
if ($Query -notmatch '\s') {
    $searches += @{ Args = "user:$Query"; Label = "Searching user '$Query' repos" }
}
$searches += @{ Args = "$Query addon"; Label = "Broadening search" }

foreach ($search in $searches) {
    if ($candidates.Count -ge $searchLimit) { break }
    Write-Host "  $($search.Label)..." -ForegroundColor Gray
    $remaining = $searchLimit - $candidates.Count
    $searchArgs = $search.Args
    $results = $null
    try {
        $results = gh search repos $searchArgs --language lua --limit $remaining --json fullName,description,stargazersCount,updatedAt,url 2>&1
    } catch {}
    if ($LASTEXITCODE -ne 0 -or -not $results) { continue }
    try {
        $parsed = $results | ConvertFrom-Json
        if (-not $parsed) { continue }
        $count = 0
        foreach ($r in $parsed) {
            if (-not $candidates.ContainsKey($r.fullName)) {
                $candidates[$r.fullName] = $r
                $count++
            }
        }
        if ($count -gt 0) { Write-Host "    Found $count repos" -ForegroundColor DarkGray }
    } catch {}
}

if ($candidates.Count -eq 0) {
    Write-Host ""
    Write-Host "No results found for '$Query'" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "  Validating $($candidates.Count) candidates for retail .toc files..." -ForegroundColor Gray

# Validate: check each candidate has .toc files with retail Interface version (>= 100000)
$validated = @()
foreach ($repo in $candidates.Values) {
    if ($validated.Count -ge $Limit) { break }

    $fullName = $repo.fullName
    Write-Verbose "  Checking $fullName..."

    # Get file tree
    $tocFiles = $null
    try {
        $treeOutput = gh api "repos/$fullName/git/trees/HEAD?recursive=1" --jq '[.tree[].path | select(test("\\.toc$"))]' 2>&1
        if ($LASTEXITCODE -eq 0 -and $treeOutput) {
            $tocFiles = $treeOutput | ConvertFrom-Json
        }
    } catch {}

    if (-not $tocFiles -or $tocFiles.Count -eq 0) {
        Write-Verbose "    No .toc files, skipping"
        continue
    }

    # Check first .toc for retail Interface version
    $isRetail = $false
    $tocPath = $tocFiles | Select-Object -First 1
    try {
        $tocContent = gh api "repos/$fullName/contents/$tocPath" --jq '.content' 2>&1
        if ($LASTEXITCODE -eq 0 -and $tocContent) {
            $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($tocContent))
            $interfaceLine = ($decoded -split "`n") | Where-Object { $_ -match '^\s*##\s*Interface\s*:' } | Select-Object -First 1
            if ($interfaceLine) {
                # Extract all version numbers from the line
                $versions = [regex]::Matches($interfaceLine, '\d+') | ForEach-Object { [int]$_.Value }
                # Retail versions are >= 100000 (e.g., 110207, 120000)
                $isRetail = ($versions | Where-Object { $_ -ge 100000 }).Count -gt 0
            }
        }
    } catch {}

    if (-not $isRetail) {
        Write-Verbose "    No retail Interface version, skipping"
        continue
    }

    $validated += $repo
    Write-Host "    ✓ $fullName" -ForegroundColor DarkGreen
}

if ($validated.Count -eq 0) {
    Write-Host ""
    Write-Host "No retail WoW addons found for '$Query'" -ForegroundColor Yellow
    return
}

# Load addon-repos.json to mark already-installed addons
$profileDir = if ($IsWindows -or $env:OS -match 'Windows') {
    Join-Path $HOME "Documents" "PowerShell"
} else {
    Join-Path $HOME ".config" "powershell"
}
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

Write-Host ""
Write-Host "Results ($($validated.Count) retail addons):" -ForegroundColor Cyan
Write-Host ""

$index = 0
foreach ($repo in $validated) {
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
