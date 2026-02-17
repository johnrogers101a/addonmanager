# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

- **Setup the environment**
  ```powershell
  # Clone the repo and checkout the development branch
  git clone <repo-url>
  cd addonmanager
  git checkout feature/rebirth

  # Run the PowerShell setup script (creates Azure resources if needed)
  ./Setup.ps1
  ```
- **Sync WoW configuration**
  - Download from Azure: `Wow-Download` or `Invoke-WowDownload`
  - Upload to Azure (maintainers): `Wow-Upload` or `Invoke-WowUpload`
- **Generate addons metadata**
  ```powershell
  Update-AddonsJson   # Regenerates addons.json from Interface/AddOns folders
  ```
- **List installations / addons**
  ```powershell
  Get-WowInstallations
  Get-InstalledAddons
  ```
- **Create or view configuration**
  ```powershell
  New-WowConfig   # Creates initial wow.json if missing
  Get-WowConfig   # Shows current settings
  ```
- **Azure CLI prerequisites** (run once per machine)
  - Windows: `winget install Microsoft.AzureCLI`
  - macOS: `brew install azure-cli`
  - Linux: `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`

## High‑Level Architecture

- **Script‑based design** – All functionality lives in PowerShell scripts under `Scripts/WoW`. Each script performs a single responsibility (e.g., downloading, uploading, parsing `.toc` files).
- **Configuration (`wow.json`)** – Stored in the user’s PowerShell profile directory. It defines the WoW root path, installation mappings, and Azure storage details.
- **Idempotent sync process**
  - *Download*: Preserves `Config.wtf`, clears the local WTF folder, downloads blobs from Azure, restores `Config.wtf`, then generates `addons.json`.
  - *Upload*: Creates Azure resources if missing, deletes existing blobs, uploads the entire WTF folder while excluding `Config.wtf`.
- **Azure CLI integration** – All Azure interactions (`az storage blob …`) are performed via the Azure CLI; no SDKs or custom HTTP code.
- **Metadata generation** – `Get-TocMetadata.ps1` parses each addon's `.toc` file to extract title, version, author, interface version, etc., which feeds into `addons.json` used for later automation.

## Important Files & Directories

- `Scripts/WoW/` – Core PowerShell scripts implementing the commands listed above.
- `WTF/` – Local copy of WoW configuration folders (`retail`, `classic`, …). This directory is overwritten on sync.
- `README.md` – Provides user‑facing documentation; referenced for quick start and troubleshooting steps.

## Cursor / Copilot Rules (if present)

*No dedicated `.cursor/rules/` or `.github/copilot-instructions.md` were found in this repository.*

---

*Claude Code should use the commands above for typical development tasks, respect the idempotent nature of sync operations, and rely on the architecture description to navigate the PowerShell scripts efficiently.*