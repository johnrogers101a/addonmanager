#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Downloads and installs WoW addons from GitHub releases.

.DESCRIPTION
    Reads addon-repos.json and for each addon with a valid GitHub repository:
    1. Downloads the latest release zip via gh CLI
    2. Extracts the addon folder(s) to Interface/AddOns
    
    Addons without a GitHub repo are skipped with a warning.
    Uses GitHub CLI (gh) for authenticated, rate-limit-friendly downloads.
    
    Cross-platform: works on Windows, macOS, and Linux.

.PARAMETER Installation
    WoW installation to install addons for (retail, classic, classicCata, beta, ptr, all)
    Default: retail

.PARAMETER Addon
    Install a specific addon by name (must match a key in addon-repos.json).
    If not specified, installs all addons.

.PARAMETER Force
    Re-download and overwrite addons even if already installed.

.PARAMETER WhatIf
    Preview which addons would be installed without downloading.

.EXAMPLE
    Get-Addons
    Install all addons for retail

.EXAMPLE
    Get-Addons -Installation classic
    Install all addons for classic

.EXAMPLE
    Get-Addons -Addon BugSack
    Install only BugSack

.EXAMPLE
    Get-Addons -Force
    Re-download all addons even if present
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('retail', 'classic', 'classicCata', 'beta', 'ptr', 'all')]
    [string]$Installation = 'retail',

    [Parameter()]
    [string]$Addon,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WoW Addon Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Verify gh CLI ────────────────────────────────────────────────────────────

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Error: GitHub CLI (gh) not found" -ForegroundColor Red
    Write-Host ""
    if ($IsWindows -or $env:OS -match 'Windows') {
        Write-Host "  Install with: winget install GitHub.cli" -ForegroundColor White
    } elseif ($IsMacOS) {
        Write-Host "  Install with: brew install gh" -ForegroundColor White
    } else {
        Write-Host "  Install with: sudo dnf install gh  (or)  sudo apt install gh" -ForegroundColor White
    }
    Write-Host "  Then run: gh auth login" -ForegroundColor White
    return
}
Write-Verbose "gh CLI found: $((Get-Command gh).Source)"

# Verify gh is authenticated
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: GitHub CLI not authenticated" -ForegroundColor Red
    Write-Host "  Run: gh auth login" -ForegroundColor White
    return
}
Write-Verbose "gh CLI authenticated"

# ── Load configuration ───────────────────────────────────────────────────────

Write-Host "Loading configuration..." -ForegroundColor Cyan

$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$configScript = Join-Path $profileDir "Scripts" "WoW" "Get-WowConfig.ps1"

if (-not (Test-Path $configScript)) {
    Write-Host "Error: Get-WowConfig.ps1 not found" -ForegroundColor Red
    Write-Host "  Run Setup.ps1 from the addonmanager repository first." -ForegroundColor White
    return
}

try {
    $config = & $configScript
    Write-Host "  ✓ wow.json loaded" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Run Setup.ps1 from the addonmanager repository first." -ForegroundColor White
    return
}

Write-Verbose "WoW root: $($config.wowRoot)"

# ── Load addon-repos.json ────────────────────────────────────────────────────

$addonReposPath = Join-Path $profileDir "addon-repos.json"
Write-Verbose "addon-repos.json path: $addonReposPath"

if (-not (Test-Path $addonReposPath)) {
    Write-Host "Error: addon-repos.json not found at: $addonReposPath" -ForegroundColor Red
    Write-Host "  Run Setup.ps1 from the addonmanager repository first." -ForegroundColor White
    return
}

$addonRepos = Get-Content $addonReposPath -Raw | ConvertFrom-Json
Write-Host "  ✓ addon-repos.json loaded" -ForegroundColor Green
Write-Host ""

# ── Determine installations ──────────────────────────────────────────────────

$installationsToProcess = @()

if ($Installation -eq 'all') {
    $installationsToProcess = $config.installations.PSObject.Properties.Name
} else {
    if ($config.installations.PSObject.Properties.Name -contains $Installation) {
        $installationsToProcess = @($Installation)
    } else {
        Write-Host "Error: Installation '$Installation' not found in configuration" -ForegroundColor Red
        return
    }
}

# ── Build addon list ─────────────────────────────────────────────────────────

$addonEntries = $addonRepos.addons.PSObject.Properties

if ($Addon) {
    $match = $addonEntries | Where-Object { $_.Name -eq $Addon }
    if (-not $match) {
        Write-Host "Error: Addon '$Addon' not found in addon-repos.json" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available addons:" -ForegroundColor Cyan
        $addonEntries | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
        return
    }
    $addonEntries = @($match)
}

$totalAddons = @($addonEntries).Count
$withRepo = @($addonEntries | Where-Object { $_.Value.github.owner -and $_.Value.github.repo }).Count
$withoutRepo = $totalAddons - $withRepo

Write-Host "Addons: $totalAddons total, $withRepo with GitHub repos, $withoutRepo skipped" -ForegroundColor Cyan
Write-Host ""

# ── Process each installation ────────────────────────────────────────────────

foreach ($installKey in $installationsToProcess) {
    $installInfo = $config.installations.$installKey
    $installPath = Join-Path $config.wowRoot $installInfo.path
    $addonsPath = Join-Path $installPath "Interface" "AddOns"

    Write-Host "Installation: $($installInfo.description)" -ForegroundColor Cyan
    Write-Verbose "  Install path: $installPath"
    Write-Verbose "  AddOns path: $addonsPath"

    if (-not (Test-Path $installPath)) {
        Write-Host "  ⚠ Installation path not found: $installPath" -ForegroundColor Yellow
        Write-Host ""
        continue
    }

    # Ensure AddOns directory exists
    if (-not (Test-Path $addonsPath)) {
        New-Item -ItemType Directory -Path $addonsPath -Force | Out-Null
        Write-Verbose "  Created AddOns directory: $addonsPath"
    }

    $installed = 0
    $skipped = 0
    $failed = 0
    $warnings = 0

    foreach ($entry in $addonEntries) {
        $addonName = $entry.Name
        $addonInfo = $entry.Value

        # Skip addons without GitHub repos
        if (-not $addonInfo.github.owner -or -not $addonInfo.github.repo) {
            Write-Host "  ⚠ $addonName - no GitHub repository configured, skipping" -ForegroundColor Yellow
            $warnings++
            continue
        }

        $owner = $addonInfo.github.owner
        $repo = $addonInfo.github.repo
        $installFolder = $addonInfo.download.installPath
        $assetPattern = $addonInfo.download.assetPattern
        $excludePatterns = @($addonInfo.download.excludePatterns | Where-Object { $_ })

        if (-not $installFolder) { $installFolder = $addonName }
        if (-not $assetPattern) { $assetPattern = "*.zip" }

        $addonDestPath = Join-Path $addonsPath $installFolder
        Write-Verbose "  $addonName -> $owner/$repo -> $addonDestPath"

        # Skip if already installed (unless -Force)
        if ((Test-Path $addonDestPath) -and -not $Force) {
            Write-Host "  ✓ $addonName - already installed" -ForegroundColor Gray
            $skipped++
            continue
        }

        if ($WhatIf) {
            Write-Host "  [WhatIf] Would install $addonName from $owner/$repo" -ForegroundColor Yellow
            continue
        }

        # Get latest release info
        Write-Verbose "  Fetching latest release for $owner/$repo..."
        $releaseJson = gh release view --repo "$owner/$repo" --json tagName,assets 2>&1
        $hasRelease = ($LASTEXITCODE -eq 0)
        $useClone = $false

        if ($hasRelease) {
            $release = $releaseJson | ConvertFrom-Json
            $tag = $release.tagName

            # Find matching asset, respecting exclude patterns
            $assets = $release.assets | Where-Object { $_.name -like $assetPattern }
            foreach ($exclude in $excludePatterns) {
                $assets = $assets | Where-Object { $_.name -notlike $exclude }
            }
            $asset = $assets | Select-Object -First 1

            if (-not $asset) {
                Write-Verbose "  No matching zip asset in release $tag, falling back to clone"
                $useClone = $true
            }
        } else {
            Write-Verbose "  No releases found, falling back to clone"
            $useClone = $true
        }

        # Download to temp directory
        $tempDir = Join-Path ([IO.Path]::GetTempPath()) "wow-addon-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        try {
            if (-not $useClone) {
                # ── Release download path ────────────────────────────────────
                Write-Verbose "  Downloading release: $($asset.name) ($tag)"

                gh release download $tag --repo "$owner/$repo" --pattern $asset.name --dir $tempDir 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  ✗ $addonName - release download failed" -ForegroundColor Red
                    $failed++
                    continue
                }

                $zipFile = Join-Path $tempDir $asset.name
                if (-not (Test-Path $zipFile)) {
                    Write-Host "  ✗ $addonName - downloaded file not found" -ForegroundColor Red
                    $failed++
                    continue
                }

                # Extract zip
                $extractDir = Join-Path $tempDir "extract"
                [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $extractDir)

                # Find the addon folder in the extracted contents
                $extractedFolders = Get-ChildItem -Path $extractDir -Directory

                if (-not $extractedFolders) {
                    Write-Host "  ✗ $addonName - zip contains no folders" -ForegroundColor Red
                    $failed++
                    continue
                }

                # Look for the specific installPath folder, or use all top-level folders
                $targetFolder = $extractedFolders | Where-Object { $_.Name -eq $installFolder }

                if ($targetFolder) {
                    if (Test-Path $addonDestPath) {
                        Remove-Item -Path $addonDestPath -Recurse -Force
                    }
                    Copy-Item -Path $targetFolder.FullName -Destination $addonDestPath -Recurse -Force
                    Write-Host "  ✓ $addonName ($tag)" -ForegroundColor Green
                    $installed++
                } elseif ($extractedFolders.Count -eq 1) {
                    if (Test-Path $addonDestPath) {
                        Remove-Item -Path $addonDestPath -Recurse -Force
                    }
                    Copy-Item -Path $extractedFolders[0].FullName -Destination $addonDestPath -Recurse -Force
                    Write-Host "  ✓ $addonName ($tag) [from $($extractedFolders[0].Name)]" -ForegroundColor Green
                    $installed++
                } else {
                    $folderNames = ($extractedFolders | ForEach-Object { $_.Name }) -join ', '
                    Write-Host "  ⚠ $addonName - expected folder '$installFolder' not found in zip (contains: $folderNames)" -ForegroundColor Yellow
                    $warnings++
                }
            } else {
                # ── Clone fallback path ──────────────────────────────────────
                $branch = $addonInfo.github.branch
                if (-not $branch) { $branch = "main" }

                Write-Host "  ℹ $addonName - no release, cloning $owner/$repo ($branch)..." -ForegroundColor Cyan

                $cloneDir = Join-Path $tempDir "clone"
                gh repo clone "$owner/$repo" $cloneDir -- --depth 1 --branch $branch --quiet 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  ✗ $addonName - clone failed" -ForegroundColor Red
                    $failed++
                    continue
                }

                # Check if the addon .toc is at the repo root or in a subfolder
                $rootToc = Get-ChildItem -Path $cloneDir -Filter "*.toc" -File -ErrorAction SilentlyContinue | Select-Object -First 1
                $subFolder = Join-Path $cloneDir $installFolder

                if ((Test-Path $subFolder) -and (Get-ChildItem -Path $subFolder -Filter "*.toc" -File -ErrorAction SilentlyContinue)) {
                    # Addon is in a subfolder matching installPath
                    if (Test-Path $addonDestPath) {
                        Remove-Item -Path $addonDestPath -Recurse -Force
                    }
                    Copy-Item -Path $subFolder -Destination $addonDestPath -Recurse -Force
                } elseif ($rootToc) {
                    # Addon code is at repo root — copy entire repo as the addon folder
                    if (Test-Path $addonDestPath) {
                        Remove-Item -Path $addonDestPath -Recurse -Force
                    }
                    Copy-Item -Path $cloneDir -Destination $addonDestPath -Recurse -Force
                } else {
                    Write-Host "  ✗ $addonName - no .toc file found in cloned repo" -ForegroundColor Red
                    $failed++
                    continue
                }

                # Remove .git directory from installed addon
                $gitDir = Join-Path $addonDestPath ".git"
                if (Test-Path $gitDir) {
                    Remove-Item -Path $gitDir -Recurse -Force -ErrorAction SilentlyContinue
                }

                Write-Host "  ✓ $addonName (cloned $branch)" -ForegroundColor Green
                $installed++
            }
        }
        catch {
            Write-Host "  ✗ $addonName - $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
        finally {
            if (Test-Path $tempDir) {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host ""
    Write-Host "  Results: $installed installed, $skipped already present, $warnings warnings, $failed failed" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Addon Install Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
