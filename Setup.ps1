#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs WoW addon management commands to PowerShell profile.

.DESCRIPTION
    Fully automated setup that:
    1. Copies WoW management scripts to PowerShell profile directory
    2. Registers Wow-Download and Wow-Upload commands in the profile
    3. Auto-detects WoW installation (prompts if not found)
    4. Creates wow.json configuration
    5. Verifies Azure CLI and authentication
    
    After setup, Wow-Download works immediately with no further configuration.
    
    Cross-platform: works on Windows, macOS, and Linux.
    This script is idempotent - safe to run multiple times.

.EXAMPLE
    ./Setup.ps1
    
.EXAMPLE
    ./Setup.ps1 -Verbose

.OUTPUTS
    None - Installs scripts, configures profile, creates wow.json
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WoW Addon Management Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Resolve profile directories ──────────────────────────────────────

$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
$wowScriptsDir = Join-Path $profileDir "Scripts" "WoW"
$profileScriptsDir = Join-Path $profileDir "Scripts" "Profile"
$sourceDir = Join-Path $PSScriptRoot "Scripts" "WoW"

Write-Verbose "Profile directory: $profileDir"
Write-Verbose "WoW scripts target: $wowScriptsDir"
Write-Verbose "Profile scripts target: $profileScriptsDir"
Write-Verbose "Source directory: $sourceDir"

Write-Host "Profile Directory: " -NoNewline
Write-Host $profileDir -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $sourceDir)) {
    Write-Host "Error: Scripts/WoW directory not found in: $PSScriptRoot" -ForegroundColor Red
    Write-Host "Please run this script from the addonmanager repository root." -ForegroundColor Red
    exit 1
}
Write-Verbose "Source directory verified: $sourceDir"

# ── Step 2: Copy scripts to profile ──────────────────────────────────────────

Write-Host "Installing scripts..." -ForegroundColor Cyan

foreach ($dir in @($wowScriptsDir, $profileScriptsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Verbose "Created directory: $dir"
    }
}

$scriptFiles = Get-ChildItem -Path $sourceDir -Filter "*.ps1" -File
foreach ($file in $scriptFiles) {
    $destPath = Join-Path $wowScriptsDir $file.Name
    Write-Verbose "Copying: $($file.FullName) -> $destPath"
    try {
        Copy-Item -Path $file.FullName -Destination $destPath -Force
        Write-Host "  ✓ $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to copy $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Copy addon-repos.json to profile directory
$addonReposSrc = Join-Path $PSScriptRoot "addon-repos.json"
$addonReposDest = Join-Path $profileDir "addon-repos.json"
if (Test-Path $addonReposSrc) {
    Copy-Item -Path $addonReposSrc -Destination $addonReposDest -Force
    Write-Host "  ✓ addon-repos.json" -ForegroundColor Green
    Write-Verbose "Copied addon-repos.json to: $addonReposDest"
} else {
    Write-Host "  ⚠ addon-repos.json not found in repo (Get-Addons will not work)" -ForegroundColor Yellow
}

Write-Host ""

# ── Step 3: Register commands in Initialize-PowerShellProfile.ps1 ────────────

Write-Host "Registering commands..." -ForegroundColor Cyan

$initScript = Join-Path $profileScriptsDir "Initialize-PowerShellProfile.ps1"
Write-Verbose "Init script: $initScript"

if (-not (Test-Path $initScript)) {
    Write-Host "  ⚠ Initialize-PowerShellProfile.ps1 not found at: $initScript" -ForegroundColor Yellow
    Write-Host "  Scripts installed but commands not auto-registered." -ForegroundColor Yellow
    Write-Host "  You can call scripts directly from: $wowScriptsDir" -ForegroundColor Yellow
} else {
    $initContent = Get-Content -Path $initScript -Raw

    if ($initContent -match 'function Wow-Download' -and $initContent -match 'function Get-Addons' -and $initContent -match 'function Wow-Purge') {
        Write-Host "  ℹ Commands already registered" -ForegroundColor Yellow
    } else {
        # Remove existing WoW block if present (to re-register with new commands)
        if ($initContent -match '(?ms)# WoW addon management commands.*?(?=\n# Display loaded custom commands|\z)') {
            $initContent = $initContent -replace '(?ms)\r?\n# WoW addon management commands.*?(?=\r?\n# Display loaded custom commands|\z)', ''
        }

        $wowBlock = @'

# WoW addon management commands
function Wow-Download {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-WowDownload.ps1"
    & $scriptPath @args
}

function Wow-Upload {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-WowUpload.ps1"
    & $scriptPath @args
}

function New-WowConfig {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "New-WowConfig.ps1"
    & $scriptPath @args
}

function Get-WowConfig {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Get-WowConfig.ps1"
    & $scriptPath @args
}

function Get-WowInstallations {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Get-WowInstallations.ps1"
    & $scriptPath @args
}

function Get-InstalledAddons {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Get-InstalledAddons.ps1"
    & $scriptPath @args
}

function Update-AddonsJson {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Update-AddonsJson.ps1"
    & $scriptPath @args
}

function Get-Addons {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-GetAddons.ps1"
    & $scriptPath @args
}

function Wow-Purge {
    $scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "WoW" "Invoke-WowPurge.ps1"
    & $scriptPath @args
}
'@
        if ($initContent -match '(?m)^# Display loaded custom commands') {
            $initContent = $initContent -replace '(?m)^# Display loaded custom commands', "$wowBlock`n`n# Display loaded custom commands"
        } else {
            $initContent += $wowBlock
        }

        Set-Content -Path $initScript -Value $initContent -Encoding UTF8 -NoNewline
        Write-Host "  ✓ Commands registered" -ForegroundColor Green
    }
}

# Create Show-Commands wrapper scripts
foreach ($cmd in @(
    @{ Name = "Wow-Download"; Synopsis = "Sync WTF configuration from Azure"; Script = "Invoke-WowDownload.ps1" },
    @{ Name = "Wow-Upload"; Synopsis = "Upload WTF configuration to Azure"; Script = "Invoke-WowUpload.ps1" },
    @{ Name = "Get-Addons"; Synopsis = "Download and install WoW addons from GitHub"; Script = "Invoke-GetAddons.ps1" },
    @{ Name = "Wow-Purge"; Synopsis = "Delete Azure storage account and start fresh"; Script = "Invoke-WowPurge.ps1" }
)) {
    $wrapper = @"
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    $($cmd.Synopsis)

.DESCRIPTION
    $($cmd.Synopsis)
#>
param()
`$wowScript = Join-Path (Split-Path -Parent `$PSScriptRoot) "WoW" "$($cmd.Script)"
& `$wowScript @args
"@
    $wrapperPath = Join-Path $profileScriptsDir "$($cmd.Name).ps1"
    Write-Verbose "Creating wrapper: $wrapperPath"
    $wrapper | Set-Content -Path $wrapperPath -Encoding UTF8
    Write-Host "  ✓ $($cmd.Name).ps1" -ForegroundColor Green
}

# Remove old wrappers
foreach ($oldWrapper in @("Invoke-WowDownload.ps1", "Invoke-WowUpload.ps1")) {
    $oldPath = Join-Path $profileScriptsDir $oldWrapper
    if (Test-Path $oldPath) {
        Remove-Item -Path $oldPath -Force
        Write-Verbose "Removed old wrapper: $oldPath"
    }
}

# Clean up old dot-source init from profile.ps1
$profilePath = $global:PROFILE.CurrentUserAllHosts
if (Test-Path $profilePath) {
    $profileContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent -match 'Initialize-WowProfile\.ps1') {
        $profileContent = $profileContent -replace '(?ms)\r?\n# Initialize WoW addon management\r?\n.*?Initialize-WowProfile\.ps1.*?\r?\n\}\r?\n?', ''
        Set-Content -Path $profilePath -Value $profileContent.TrimEnd() -Encoding UTF8
        Write-Verbose "Cleaned up old dot-source init from profile.ps1"
    }
}

Write-Host ""

# ── Step 4: Check dependencies and offer to install ──────────────────────────

Write-Host "Checking dependencies..." -ForegroundColor Cyan

$missingDeps = @()

# Azure CLI
if (Get-Command az -ErrorAction SilentlyContinue) {
    Write-Host "  ✓ Azure CLI: $((Get-Command az).Source)" -ForegroundColor Green
} else {
    Write-Host "  ✗ Azure CLI not found" -ForegroundColor Red
    $missingDeps += 'az'
}

# GitHub CLI
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "  ✓ GitHub CLI: $((Get-Command gh).Source)" -ForegroundColor Green
} else {
    Write-Host "  ✗ GitHub CLI not found" -ForegroundColor Red
    $missingDeps += 'gh'
}

if ($missingDeps.Count -gt 0) {
    Write-Host ""
    $installChoice = Read-Host "  Install missing dependencies? (Y/n)"
    if ($installChoice -eq '' -or $installChoice -eq 'y' -or $installChoice -eq 'Y') {
        foreach ($dep in $missingDeps) {
            if ($IsWindows -or $env:OS -match 'Windows') {
                switch ($dep) {
                    'az' { Write-Host "  Installing Azure CLI..." -ForegroundColor Cyan; winget install Microsoft.AzureCLI --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null }
                    'gh' { Write-Host "  Installing GitHub CLI..." -ForegroundColor Cyan; winget install GitHub.cli --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null }
                }
            } elseif ($IsMacOS) {
                switch ($dep) {
                    'az' { Write-Host "  Installing Azure CLI..." -ForegroundColor Cyan; brew install azure-cli 2>&1 | Out-Null }
                    'gh' { Write-Host "  Installing GitHub CLI..." -ForegroundColor Cyan; brew install gh 2>&1 | Out-Null }
                }
            } else {
                switch ($dep) {
                    'az' {
                        Write-Host "  Installing Azure CLI..." -ForegroundColor Cyan
                        if (Get-Command dnf -ErrorAction SilentlyContinue) {
                            sudo dnf install -y azure-cli 2>&1 | Out-Null
                        } elseif (Get-Command apt -ErrorAction SilentlyContinue) {
                            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash 2>&1 | Out-Null
                        } else {
                            Write-Host "  ⚠ Could not detect package manager. Install manually: https://aka.ms/azure-cli" -ForegroundColor Yellow
                        }
                    }
                    'gh' {
                        Write-Host "  Installing GitHub CLI..." -ForegroundColor Cyan
                        if (Get-Command dnf -ErrorAction SilentlyContinue) {
                            sudo dnf install -y gh 2>&1 | Out-Null
                        } elseif (Get-Command apt -ErrorAction SilentlyContinue) {
                            sudo apt install -y gh 2>&1 | Out-Null
                        } else {
                            Write-Host "  ⚠ Could not detect package manager. Install manually: https://cli.github.com" -ForegroundColor Yellow
                        }
                    }
                }
            }

            if (Get-Command $dep -ErrorAction SilentlyContinue) {
                Write-Host "  ✓ $dep installed" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ $dep may need a shell restart to be available" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host ""
        Write-Host "  Manual install instructions:" -ForegroundColor White
        if ($IsWindows -or $env:OS -match 'Windows') {
            if ($missingDeps -contains 'az') { Write-Host "    winget install Microsoft.AzureCLI" -ForegroundColor Yellow }
            if ($missingDeps -contains 'gh') { Write-Host "    winget install GitHub.cli" -ForegroundColor Yellow }
        } elseif ($IsMacOS) {
            if ($missingDeps -contains 'az') { Write-Host "    brew install azure-cli" -ForegroundColor Yellow }
            if ($missingDeps -contains 'gh') { Write-Host "    brew install gh" -ForegroundColor Yellow }
        } else {
            if ($missingDeps -contains 'az') { Write-Host "    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash" -ForegroundColor Yellow }
            if ($missingDeps -contains 'gh') { Write-Host "    sudo apt install gh  (or)  sudo dnf install gh" -ForegroundColor Yellow }
        }
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "Setup Partially Complete" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  Install dependencies, then run Setup.ps1 again." -ForegroundColor White
        Write-Host ""
        exit 0
    }
}
Write-Host ""

# ── Step 5: Verify Azure authentication and get subscription ─────────────────

Write-Host "Verifying Azure authentication..." -ForegroundColor Cyan

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "  ⚠ Azure CLI still not available — restart your shell and run Setup.ps1 again" -ForegroundColor Yellow
    exit 0
}

$azAccountJson = az account show --output json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ⚠ Not logged into Azure" -ForegroundColor Yellow
    Write-Host "  Run: az login" -ForegroundColor Yellow
    Write-Host "  Then run Setup.ps1 again." -ForegroundColor White
    exit 0
}

$azAccount = $azAccountJson | ConvertFrom-Json
$currentSub = $azAccount.name
$currentSubId = $azAccount.id
$azureEmail = $azAccount.user.name

Write-Host "  ✓ Logged into Azure" -ForegroundColor Green
Write-Host "  Subscription: $currentSub ($currentSubId)" -ForegroundColor Gray
Write-Host "  Account: $azureEmail" -ForegroundColor Gray
Write-Host ""

$subConfirm = Read-Host "  Use subscription '$currentSub'? (Y/n)"
if ($subConfirm -ne '' -and $subConfirm -ne 'y' -and $subConfirm -ne 'Y') {
    # List available subscriptions
    Write-Host ""
    Write-Host "  Available subscriptions:" -ForegroundColor Cyan
    az account list --query "[].{Name:name, Id:id}" --output table 2>&1
    Write-Host ""
    $newSub = Read-Host "  Enter subscription name or ID"
    az account set --subscription $newSub 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Failed to set subscription: $newSub" -ForegroundColor Red
        exit 1
    }
    $azAccountJson = az account show --output json 2>&1
    $azAccount = $azAccountJson | ConvertFrom-Json
    $currentSub = $azAccount.name
    $currentSubId = $azAccount.id
    $azureEmail = $azAccount.user.name
    Write-Host "  ✓ Subscription set: $currentSub" -ForegroundColor Green
}
Write-Host ""

# ── Step 6: Derive per-user storage account name ─────────────────────────────

# Extract username from Azure email (before @), lowercase, alphanumeric only
$username = ($azureEmail -split '@')[0] -replace '[^a-z0-9]', ''
# Storage account: st{username}wowwus3 — max 24 chars total
# Prefix "st" (2) + suffix "wowwus3" (7) = 9 fixed chars, 15 available for username
$maxUsernameLen = 15
if ($username.Length -gt $maxUsernameLen) {
    $username = $username.Substring(0, $maxUsernameLen)
}
$storageAccountName = "st${username}wowwus3"

Write-Host "Storage account: $storageAccountName (derived from $azureEmail)" -ForegroundColor Cyan
Write-Verbose "Username extracted: $username"
Write-Verbose "Storage account name length: $($storageAccountName.Length) (max 24)"
Write-Host ""

# ── Step 7: Detect WoW installation and create wow.json ──────────────────────

Write-Host "Configuring WoW installation..." -ForegroundColor Cyan

$configPath = Join-Path $profileDir "wow.json"
Write-Verbose "wow.json path: $configPath"

$detectScript = Join-Path $wowScriptsDir "Get-WowInstallations.ps1"
Write-Verbose "Detection script: $detectScript"

if (-not (Test-Path $detectScript)) {
    Write-Host "  ✗ Get-WowInstallations.ps1 not found at: $detectScript" -ForegroundColor Red
    exit 1
}

# Build list of common WoW paths to try
$candidatePaths = @()

if ($IsWindows -or $env:OS -match 'Windows') {
    $candidatePaths += "C:\Program Files (x86)\World of Warcraft"
    $candidatePaths += "C:\Program Files\World of Warcraft"
    foreach ($drive in @('D', 'E', 'F', 'G')) {
        $candidatePaths += "${drive}:\Games\World of Warcraft"
        $candidatePaths += "${drive}:\World of Warcraft"
    }
} elseif ($IsMacOS) {
    $candidatePaths += "/Applications/World of Warcraft"
} else {
    $candidatePaths += Join-Path $HOME "Games" "world-of-warcraft"
    $candidatePaths += Join-Path $HOME "Games" "battlenet" "drive_c" "Program Files (x86)" "World of Warcraft"
    $steamBase = Join-Path $HOME ".steam" "steam" "steamapps" "compatdata"
    if (Test-Path $steamBase) {
        $protonDirs = Get-ChildItem -Path $steamBase -Directory -ErrorAction SilentlyContinue
        foreach ($d in $protonDirs) {
            $candidatePaths += Join-Path $d.FullName "pfx" "drive_c" "Program Files (x86)" "World of Warcraft"
        }
    }
    $flatpakSteamBase = Join-Path $HOME ".var" "app" "com.valvesoftware.Steam" ".local" "share" "Steam" "steamapps" "compatdata"
    if (Test-Path $flatpakSteamBase) {
        $protonDirs = Get-ChildItem -Path $flatpakSteamBase -Directory -ErrorAction SilentlyContinue
        foreach ($d in $protonDirs) {
            $candidatePaths += Join-Path $d.FullName "pfx" "drive_c" "Program Files (x86)" "World of Warcraft"
        }
    }
}

Write-Verbose "Candidate paths to search:"
foreach ($p in $candidatePaths) { Write-Verbose "  $p" }

# If wow.json already exists and has a valid wowRoot, use it
$wowRoot = $null
$installations = $null

if (Test-Path $configPath) {
    $existingConfig = Get-Content $configPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($existingConfig.wowRoot -and (Test-Path $existingConfig.wowRoot)) {
        $found = & $detectScript -WowRoot $existingConfig.wowRoot -ErrorAction SilentlyContinue
        if ($found -and $found.Count -gt 0) {
            $wowRoot = $existingConfig.wowRoot
            $installations = $found
            Write-Verbose "Using existing wow.json wowRoot: $wowRoot"
        }
    }
}

# Try each candidate path
if (-not $wowRoot) {
    foreach ($candidate in $candidatePaths) {
        Write-Verbose "Checking: $candidate"
        if (Test-Path $candidate) {
            $found = & $detectScript -WowRoot $candidate -ErrorAction SilentlyContinue
            if ($found -and $found.Count -gt 0) {
                $wowRoot = $candidate
                $installations = $found
                break
            }
        }
    }
}

# If not found, ask user
if (-not $wowRoot) {
    Write-Host "  ⚠ Could not auto-detect WoW installation" -ForegroundColor Yellow
    Write-Host ""

    while (-not $wowRoot) {
        $userPath = Read-Host "  Enter WoW installation root directory"

        if ([string]::IsNullOrWhiteSpace($userPath)) {
            Write-Host "  ✗ Path cannot be empty" -ForegroundColor Red
            continue
        }

        $userPath = $userPath.Trim().Trim('"').Trim("'")
        Write-Verbose "User provided path (normalized): $userPath"

        if (-not (Test-Path $userPath)) {
            Write-Host "  ✗ Directory not found: $userPath" -ForegroundColor Red
            continue
        }

        if (-not (Test-Path $userPath -PathType Container)) {
            Write-Host "  ✗ Not a directory: $userPath" -ForegroundColor Red
            continue
        }

        $found = & $detectScript -WowRoot $userPath -ErrorAction SilentlyContinue
        if (-not $found -or $found.Count -eq 0) {
            Write-Host "  ✗ No WoW installations found in: $userPath" -ForegroundColor Red
            Write-Host "    Expected subfolders: _retail_, _classic_, _classic_era_, _beta_, _ptr_" -ForegroundColor Gray
            continue
        }

        $wowRoot = $userPath
        $installations = $found
    }
}

Write-Host "  ✓ WoW root: $wowRoot" -ForegroundColor Green
foreach ($key in $installations.Keys) {
    Write-Host "  ✓ $($installations[$key].description)" -ForegroundColor Green
    Write-Verbose "  Installation '$key': $(Join-Path $wowRoot $installations[$key].path)"
}
Write-Host ""

# Create wow.json
Write-Host "Creating wow.json..." -ForegroundColor Cyan
Write-Verbose "wow.json destination: $configPath"

$config = @{
    wowRoot             = $wowRoot
    installations       = $installations
    azureSubscription   = $currentSub
    azureResourceGroup  = "rg-wow-profile"
    azureStorageAccount = $storageAccountName
    azureContainer      = "wow-config"
    azureLocation       = "westus3"
    excludeFiles        = @("Config.wtf")
}

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
Write-Host "  ✓ wow.json saved to: $configPath" -ForegroundColor Green
Write-Verbose "wow.json contents:"
Write-Verbose (Get-Content $configPath -Raw)
Write-Host ""

# ── Step 8: Verify Azure storage ─────────────────────────────────────────────

Write-Host "Verifying Azure storage..." -ForegroundColor Cyan

az account set --subscription $currentSub 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ⚠ Failed to set subscription: $currentSub" -ForegroundColor Yellow
    exit 0
}

$storageCheck = az storage account show `
    --name $config.azureStorageAccount `
    --resource-group $config.azureResourceGroup `
    --output json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ℹ Storage account '$($config.azureStorageAccount)' does not exist yet" -ForegroundColor Yellow
    Write-Host "  It will be created automatically when you run Wow-Upload." -ForegroundColor Gray
} else {
    Write-Host "  ✓ Azure storage verified: $($config.azureStorageAccount)" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Restart PowerShell, then run:" -ForegroundColor Cyan
Write-Host "  Wow-Download    " -NoNewline -ForegroundColor Yellow
Write-Host "- Sync WTF configuration from Azure" -ForegroundColor Gray
Write-Host "  Wow-Upload      " -NoNewline -ForegroundColor Yellow
Write-Host "- Upload WTF configuration to Azure" -ForegroundColor Gray
Write-Host "  Get-Addons      " -NoNewline -ForegroundColor Yellow
Write-Host "- Download and install addons from GitHub" -ForegroundColor Gray
Write-Host "  Wow-Purge       " -NoNewline -ForegroundColor Yellow
Write-Host "- Delete Azure storage account and start fresh" -ForegroundColor Gray
Write-Host ""
