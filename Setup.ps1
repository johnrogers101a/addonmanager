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

    if ($initContent -match 'function Wow-Download') {
        Write-Host "  ℹ Commands already registered" -ForegroundColor Yellow
    } else {
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
    @{ Name = "Wow-Upload"; Synopsis = "Upload WTF configuration to Azure"; Script = "Invoke-WowUpload.ps1" }
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

# ── Step 4: Detect WoW installation and create wow.json ──────────────────────

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
    # Check all drive letters
    foreach ($drive in @('D', 'E', 'F', 'G')) {
        $candidatePaths += "${drive}:\Games\World of Warcraft"
        $candidatePaths += "${drive}:\World of Warcraft"
    }
} elseif ($IsMacOS) {
    $candidatePaths += "/Applications/World of Warcraft"
} else {
    # Linux: Lutris, Steam Proton
    $candidatePaths += Join-Path $HOME "Games" "world-of-warcraft"
    $candidatePaths += Join-Path $HOME "Games" "battlenet" "drive_c" "Program Files (x86)" "World of Warcraft"
    # Steam Proton common paths
    $steamBase = Join-Path $HOME ".steam" "steam" "steamapps" "compatdata"
    if (Test-Path $steamBase) {
        $protonDirs = Get-ChildItem -Path $steamBase -Directory -ErrorAction SilentlyContinue
        foreach ($d in $protonDirs) {
            $candidatePaths += Join-Path $d.FullName "pfx" "drive_c" "Program Files (x86)" "World of Warcraft"
        }
    }
    # Flatpak Steam
    $flatpakSteamBase = Join-Path $HOME ".var" "app" "com.valvesoftware.Steam" ".local" "share" "Steam" "steamapps" "compatdata"
    if (Test-Path $flatpakSteamBase) {
        $protonDirs = Get-ChildItem -Path $flatpakSteamBase -Directory -ErrorAction SilentlyContinue
        foreach ($d in $protonDirs) {
            $candidatePaths += Join-Path $d.FullName "pfx" "drive_c" "Program Files (x86)" "World of Warcraft"
        }
    }
}

Write-Verbose "Candidate paths to search:"
foreach ($p in $candidatePaths) {
    Write-Verbose "  $p"
}

# Try each candidate path
$wowRoot = $null
$installations = $null

foreach ($candidate in $candidatePaths) {
    Write-Verbose "Checking: $candidate"
    if (Test-Path $candidate) {
        Write-Verbose "  Path exists, detecting installations..."
        $found = & $detectScript -WowRoot $candidate -ErrorAction SilentlyContinue
        if ($found -and $found.Count -gt 0) {
            $wowRoot = $candidate
            $installations = $found
            Write-Verbose "  Found $($found.Count) installation(s)"
            break
        }
        Write-Verbose "  No valid installations found"
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

        # Normalize path
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

        Write-Verbose "  Path exists and is a directory, detecting installations..."
        $found = & $detectScript -WowRoot $userPath -ErrorAction SilentlyContinue
        if (-not $found -or $found.Count -eq 0) {
            Write-Host "  ✗ No WoW installations found in: $userPath" -ForegroundColor Red
            Write-Host "    Expected subfolders: _retail_, _classic_, _classic_era_, _beta_, _ptr_" -ForegroundColor Gray
            Write-Host "    Each must contain Interface/ and WTF/ directories" -ForegroundColor Gray
            continue
        }

        $wowRoot = $userPath
        $installations = $found
    }
}

Write-Host "  ✓ WoW root: $wowRoot" -ForegroundColor Green
Write-Verbose "WoW root resolved: $wowRoot"

foreach ($key in $installations.Keys) {
    $installPath = Join-Path $wowRoot $installations[$key].path
    Write-Host "  ✓ $($installations[$key].description)" -ForegroundColor Green
    Write-Verbose "  Installation '$key': $installPath"
    Write-Verbose "    Interface: $(Join-Path $installPath 'Interface')"
    Write-Verbose "    WTF: $(Join-Path $installPath 'WTF')"
}
Write-Host ""

# Create wow.json
Write-Host "Creating wow.json..." -ForegroundColor Cyan
Write-Verbose "wow.json destination: $configPath"

$config = @{
    wowRoot             = $wowRoot
    installations       = $installations
    azureSubscription   = "4js"
    azureResourceGroup  = "rg-wow-profile"
    azureStorageAccount = "stwowprofilewus3"
    azureContainer      = "wow-config"
    excludeFiles        = @("Config.wtf")
}

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
Write-Host "  ✓ wow.json saved to: $configPath" -ForegroundColor Green
Write-Verbose "wow.json contents:"
Write-Verbose (Get-Content $configPath -Raw)
Write-Host ""

# ── Step 5: Verify Azure CLI and authentication ─────────────────────────────

Write-Host "Verifying Azure CLI..." -ForegroundColor Cyan

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "  ⚠ Azure CLI not installed" -ForegroundColor Yellow
    Write-Host ""
    if ($IsWindows -or $env:OS -match 'Windows') {
        Write-Host "  Install with: winget install Microsoft.AzureCLI" -ForegroundColor White
    } elseif ($IsMacOS) {
        Write-Host "  Install with: brew install azure-cli" -ForegroundColor White
    } else {
        Write-Host "  Install with: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  After installing, run this setup again." -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Setup Partially Complete" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Scripts and configuration are installed." -ForegroundColor White
    Write-Host "Install Azure CLI, then run Setup.ps1 again to finish." -ForegroundColor White
    Write-Host ""
    exit 0
}

$azPath = (Get-Command az).Source
Write-Host "  ✓ Azure CLI found: $azPath" -ForegroundColor Green
Write-Verbose "Azure CLI path: $azPath"

Write-Host "Verifying Azure authentication..." -ForegroundColor Cyan

$azAccount = az account show --output json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ⚠ Not logged into Azure" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Please run these commands, then run Setup.ps1 again:" -ForegroundColor White
    Write-Host "    az login" -ForegroundColor Yellow
    Write-Host "    az account set --subscription $($config.azureSubscription)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Setup Partially Complete" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Scripts and configuration are installed." -ForegroundColor White
    Write-Host "Log into Azure, then run Setup.ps1 again to finish." -ForegroundColor White
    Write-Host ""
    exit 0
}
Write-Host "  ✓ Logged into Azure" -ForegroundColor Green
Write-Verbose "Azure account: $azAccount"

az account set --subscription $config.azureSubscription 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ⚠ Failed to set subscription: $($config.azureSubscription)" -ForegroundColor Yellow
    Write-Host "  Run: az account set --subscription $($config.azureSubscription)" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Setup Partially Complete" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}
Write-Host "  ✓ Subscription set: $($config.azureSubscription)" -ForegroundColor Green
Write-Verbose "Azure subscription: $($config.azureSubscription)"

# Verify storage account exists
$storageCheck = az storage account show `
    --name $config.azureStorageAccount `
    --resource-group $config.azureResourceGroup `
    --output json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ⚠ Azure storage account '$($config.azureStorageAccount)' not found" -ForegroundColor Yellow
    Write-Host "  Run Wow-Upload first to create Azure resources." -ForegroundColor White
} else {
    Write-Host "  ✓ Azure storage verified: $($config.azureStorageAccount)" -ForegroundColor Green
    Write-Verbose "Storage account exists: $($config.azureStorageAccount)"
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
Write-Host ""
