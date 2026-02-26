# Phase 2: Addon Update Management

## Overview
Phase 2 will add automated addon update checking and installation using GitHub releases.

## Data Structure
`addon-repos.json` contains all addon-to-GitHub mappings with:
- Repository owner/name/branch
- Installed version (synced from addons.json)
- Latest version (fetched from GitHub)
- Update tracking settings
- Download patterns

## Planned Commands

### 1. Check-WowAddonUpdates
Checks for available updates for all tracked addons.

**Implementation approach:**
- Load `addon-repos.json`
- For each addon with `updateTracking.enabled = true`:
  - Use GitHub MCP: `github-mcp-server-actions_list` with `list_workflow_runs` OR search releases
  - Compare `installedVersion` vs latest release tag
  - Report addons with updates available
- Update `lastChecked` timestamp
- Save results back to `addon-repos.json`

**Required GitHub MCP calls:**
```javascript
// Get latest release for a repo
github-mcp-server-actions_get({
  method: "get_workflow",
  owner: "funkydude",
  repo: "BugSack",
  resource_id: "latest"  // or use releases API
})

// Or list releases
github-mcp-server-actions_list({
  method: "list_workflows",  // might need releases-specific call
  owner: "funkydude",
  repo: "BugSack"
})
```

**Output:**
```
Checking for addon updates...
✓ BugSack: v11.2.9 → v11.3.0 (update available)
✓ AbilityTimeline: v0.18 (up to date)
✓ TeleportMenu: v12 (up to date)
⚠ WaypointUI: No releases found
```

### 2. Update-WowAddon
Downloads and installs an addon update.

**Implementation approach:**
- Verify addon exists in `addon-repos.json`
- Get latest release from GitHub
- Download release asset (ZIP file) matching `assetPattern`
- Extract to temp directory
- Backup current addon folder (if `backupBeforeUpdate = true`)
- Replace addon folder with new version
- Update `installedVersion` in `addon-repos.json`
- Regenerate `addons.json` by calling `Update-AddonsJson.ps1`

**Parameters:**
- `-AddonName` (required): Name of addon to update
- `-Version` (optional): Specific version tag to install
- `-Force` (optional): Skip backup and confirmation prompts

**Required GitHub MCP calls:**
```javascript
// Get release info
github-mcp-server-actions_get({
  method: "get_workflow",  // or releases method
  owner: "...",
  repo: "...",
  resource_id: "v11.3.0"
})

// Download asset - will need direct URL download via bash/curl
// GitHub MCP provides download URLs, then use:
// curl -L -o /tmp/addon.zip "https://github.com/.../releases/download/..."
```

**Implementation details:**
- Download: Use `curl` or `Invoke-WebRequest` with release asset URL
- Extract: Use `Expand-Archive` (PowerShell) or `unzip` (bash)
- Backup: Copy existing folder to `~/.wow-addon-backups/{addon}/{timestamp}/`
- Install: Remove old folder, move extracted folder to AddOns directory

### 3. Update-AllWowAddons
Batch update all addons with available updates.

**Implementation approach:**
- Call `Check-WowAddonUpdates` internally
- For each addon with updates available:
  - Call `Update-WowAddon -AddonName $name`
- Report summary

**Parameters:**
- `-WhatIf` (optional): Show what would be updated without doing it
- `-ExcludeAddons` (optional): Array of addon names to skip

### 4. Watch-WowAddonUpdates
Real-time notification system for addon updates.

**Implementation approach:**
- Run as background job (Start-Job or detached process)
- Poll GitHub releases at interval (default: daily)
- Store state in `~/.wow-addon-updates-state.json`
- Send notifications when updates found

**Notification options:**
- Console output (Write-Host with color)
- macOS notification (`osascript -e 'display notification "..."'`)
- Log file at `~/.config/powershell/logs/wow-addon-updates.log`

**Parameters:**
- `-Interval` (optional): Check interval in seconds (default: 86400 = 1 day)
- `-Notify` (optional): Enable macOS notifications
- `-Stop` (optional): Stop the background watcher

## GitHub MCP Tools Analysis

### Available tools we'll use:

1. **Repository info:**
   - `github-mcp-server-get_file_contents` - Get repo metadata, release info
   - `github-mcp-server-list_branches` - Verify branch exists

2. **Releases (need to verify exact API):**
   - May need to use `search_repositories` or `get_file_contents` with releases path
   - GitHub REST API: `/repos/{owner}/{repo}/releases/latest`
   - Download URLs are in release assets array

3. **Workflow tracking (if releases use Actions):**
   - `github-mcp-server-actions_list` - List workflows/runs
   - `github-mcp-server-actions_get` - Get workflow details
   - Most addons use GitHub Actions for releases

### Data we need from GitHub:

For each addon:
- Latest release tag name (version)
- Release published date
- Release assets (ZIP files)
- Asset download URL
- Release notes/changelog (optional)

### Version comparison logic:

```powershell
function Compare-AddonVersion {
    param([string]$Installed, [string]$Latest)
    
    # Strip 'v' prefix
    $installed = $Installed -replace '^v', ''
    $latest = $Latest -replace '^v', ''
    
    # Compare semantic versions
    # Return: -1 (outdated), 0 (same), 1 (newer)
}
```

## File Structure

```
addonmanager/
├── addon-repos.json           # Main mapping file
├── Scripts/WoW/
│   ├── Check-WowAddonUpdates.ps1
│   ├── Update-WowAddon.ps1
│   ├── Update-AllWowAddons.ps1
│   ├── Watch-WowAddonUpdates.ps1
│   ├── Compare-AddonVersion.ps1    # Helper
│   └── Get-AddonRepoMapping.ps1    # Helper to load JSON
└── PHASE2-PLANNING.md         # This file
```

## Testing Plan

1. Test with single addon (BugSack - has active releases)
2. Test version comparison with various formats
3. Test download and extraction
4. Test backup/restore
5. Test with addon that has no releases
6. Test with all addons

## Edge Cases to Handle

- Addon has no GitHub releases (use tags instead?)
- Release has multiple assets (pick correct one via pattern)
- Version format differences (v1.2.3 vs 1.2.3 vs 1.2)
- Network failures during download
- Corrupted ZIP files
- Addon folder structure mismatch after extraction
- User has local modifications to addon files
- Addon dependencies (BtWQuests modules require core)

## Future Enhancements

- Support for CurseForge API (for addons not on GitHub)
- Rollback command (restore from backup)
- Diff viewer for addon changes
- Update changelog display
- Selective file updates (config preservation)
- Install new addons from GitHub URL
- Export/import addon lists for sharing setups
