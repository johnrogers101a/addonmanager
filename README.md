# WoW Addon Configuration Sync

Synchronize World of Warcraft addon configurations across multiple machines using Azure Blob Storage.

## Features

- 🔄 **Configuration Sync** - Download and sync WTF folder configurations from Azure
- 🎮 **Multi-Installation Support** - Retail, Classic Era, Classic Cataclysm, Beta, PTR
- 🛡️ **Config.wtf Protection** - Machine-specific settings never synced
- 📦 **Addon Inventory** - Automatic addon.json generation with metadata from .toc files
- ☁️ **Azure Storage** - Centralized configuration storage with Azure Blob Storage
- 🔧 **Idempotent** - Safe to run multiple times
- 💻 **Cross-Platform** - Windows and macOS support

## Quick Start

### 1. Clone Repository

```bash
git clone <repo-url>
cd addonmanager
git checkout feature/rebirth
```

### 2. Load WoW Management Functions

Add to your PowerShell profile:

```powershell
# Initialize WoW management
$wowInitScript = "C:\Path\To\addonmanager\Scripts\WoW\Initialize-WowProfile.ps1"
if (Test-Path $wowInitScript) {
    . $wowInitScript
}
```

### 3. Create Configuration

```powershell
New-WowConfig
```

This creates `wow.json` in your PowerShell profile directory with auto-detected WoW installations.

### 4. Sync Configuration

```powershell
# Sync all installations
Update-Wow

# Sync specific installation
Update-Wow -Installation retail
```

## Commands

| Command | Description |
|---------|-------------|
| `Update-Wow` | Download and sync WTF configuration from Azure |
| `New-WowConfig` | Create initial wow.json configuration |
| `Get-WowConfig` | Display current wow.json settings |
| `Get-WowInstallations` | List detected WoW installations |
| `Get-InstalledAddons` | List installed addons with metadata |
| `Update-AddonsJson` | Regenerate addons.json from Interface/AddOns |

## Configuration

### wow.json

Located in PowerShell profile directory:
- Windows: `$HOME\Documents\PowerShell\wow.json`
- macOS: `~/.config/powershell/wow.json`

Example:
```json
{
  "wowRoot": "C:\\Program Files (x86)\\World of Warcraft",
  "installations": {
    "retail": {
      "path": "_retail_",
      "description": "World of Warcraft Retail"
    }
  },
  "azureSubscription": "4js",
  "azureResourceGroup": "rg-wow-profile",
  "azureStorageAccount": "stwowprofilewus3",
  "azureContainer": "wow-config",
  "excludeFiles": ["Config.wtf"]
}
```

### addons.json

Auto-generated in each WTF folder with addon metadata:

```json
{
  "generatedAt": "2026-02-14T20:30:00Z",
  "installation": "retail",
  "addons": [
    {
      "folder": "DBM-Core",
      "title": "Deadly Boss Mods",
      "version": "10.2.30",
      "author": "Tandanu",
      "notes": "Boss mod with timers and warnings",
      "interface": "110007"
    }
  ]
}
```

## Publishing Configuration

To upload WTF configurations to Azure (maintainers only):

1. Ensure Azure CLI is installed and authenticated:
   ```powershell
   az login
   az account set --subscription 4js
   ```

2. Run the upload script from repository root:
   ```powershell
   .\Upload.ps1
   ```

This script:
- Creates Azure resources if they don't exist (idempotent)
- Deletes existing blobs in container
- Uploads all WTF configurations from repository
- Excludes Config.wtf files

## Repository Structure

```
addonmanager/
├── Scripts/
│   └── WoW/
│       ├── Initialize-WowProfile.ps1
│       ├── Update-Wow.ps1
│       ├── Get-WowConfig.ps1
│       ├── Get-WowInstallations.ps1
│       ├── New-WowConfig.ps1
│       ├── Get-TocMetadata.ps1
│       ├── Get-InstalledAddons.ps1
│       └── Update-AddonsJson.ps1
├── WTF/
│   ├── retail/
│   │   └── WTF/
│   ├── classic/
│   │   └── WTF/
│   └── ...
├── Upload.ps1
└── README.md
```

## How It Works

### Sync Process (Update-Wow)

1. Loads wow.json from profile directory
2. Verifies Azure resources exist (fails fast if not)
3. Preserves Config.wtf to temp location
4. Deletes WTF folder contents
5. Downloads all files from Azure using `az storage blob download-batch`
6. Restores Config.wtf
7. Generates addons.json from Interface/AddOns folder

### Upload Process (Upload.ps1)

1. Creates Azure resources if needed (resource group, storage account, container)
2. Deletes existing blobs using `az storage blob delete-batch`
3. Scans WTF subfolders in repository
4. Uploads all files using `az storage blob upload-batch`
5. Excludes Config.wtf from upload

## Requirements

- PowerShell 7.0+
- Azure CLI (`az`)
- World of Warcraft installation
- Azure subscription (for publishing only)

### Installing Azure CLI

**Windows:**
```powershell
winget install Microsoft.AzureCLI
```

**macOS:**
```bash
brew install azure-cli
```

## Troubleshooting

### Azure Resources Not Found

Error: "Azure storage not found"

**Solution:** Run `Upload.ps1` from the addonmanager repository to initialize Azure resources.

### Not Logged Into Azure

Error: "Not logged into Azure"

**Solution:**
```powershell
az login
az account set --subscription 4js
```

### Config.wtf Missing After Sync

Config.wtf is preserved during sync. If it's missing after sync, it was likely not present before.

### TOC Parsing Errors

Warnings about .toc parsing errors are expected for some addons. These addons are skipped but sync continues.

## Architecture

- **Script-Based Design** - No modules, always fresh execution
- **SOLID Principles** - Single responsibility per script
- **Idempotent Operations** - Safe to run multiple times
- **Complete Replacement** - No file comparison, always fresh sync
- **Azure CLI** - All Azure operations use `az` commands

## Phase 2 (Future)

Phase 2 will add addon installation management:
- Automatic addon downloads from CurseForge
- Version checking and updates
- Dependency resolution
- addons.json used to install missing addons

## License

See LICENSE file for details.

## Support

For issues or questions, please open a GitHub issue.
