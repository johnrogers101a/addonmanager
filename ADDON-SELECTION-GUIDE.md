# Quick Addon Selection Guide

Use these commands to browse the 100-addon catalog and select addons to install.

## Browse by Popularity

```bash
# Top 20 addons
cat addon-catalog.json | jq -r '.addons | to_entries | sort_by(-.value.metadata.stars) | .[:20] | .[] | "\(.value.metadata.stars)⭐ \(.key)"'

# Addons with >100 stars
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.stars > 100) | "\(.value.metadata.stars)⭐ \(.key) - \(.value.metadata.description[:70])"'
```

## Browse by Category

```bash
# UI Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("ui")) | .key'

# Bag/Inventory Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("bag") or contains("inventory")) | .key'

# Quest/Leveling Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("quest") or contains("level")) | .key'

# Raid/Dungeon Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("raid") or contains("dungeon") or contains("boss")) | .key'

# Auction House Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("auction")) | .key'

# Combat/DPS Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("dps") or contains("rotation") or contains("combat")) | .key'

# Nameplate Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("nameplate") or contains("plate")) | .key'

# Tooltip Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("tooltip") or contains("tip")) | .key'

# Unit Frame Addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("frame") or contains("unit frame")) | .key'
```

## Search for Specific Features

```bash
# Search by keyword
KEYWORD="nameplate"
cat addon-catalog.json | jq -r --arg k "$KEYWORD" '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains($k)) | "\(.key) - \(.value.metadata.description[:70])"'

# Multiple keywords (OR)
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | test("buff|debuff|aura")) | .key'
```

## Get Addon Details

```bash
# Full details for specific addon
cat addon-catalog.json | jq '.addons["WeakAuras2"]'

# Just description
cat addon-catalog.json | jq -r '.addons["DeadlyBossMods"].metadata.description'

# GitHub URL
cat addon-catalog.json | jq -r '.addons["Questie"].metadata.url'

# Owner/Repo for cloning
cat addon-catalog.json | jq -r '.addons["AdiBags"] | "\(.github.owner)/\(.github.repo)"'
```

## Filter by Stars/Activity

```bash
# Addons with 50-100 stars (moderately popular)
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.stars >= 50 and .value.metadata.stars < 100) | "\(.value.metadata.stars)⭐ \(.key)"'

# Recently updated (last 6 months)
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.lastUpdated > "2025-08-01") | "\(.key) (updated: \(.value.metadata.lastUpdated[:10]))"'

# By language
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.language == "Lua") | .key' | wc -l
```

## Create Your Selection List

```bash
# Create a file with addons you want to install
cat > /tmp/my-addon-list.txt << 'EOF'
WeakAuras2
DeadlyBossMods
Questie
AdiBags
SavedInstances
EOF

# Verify they exist in catalog
while read addon; do
  cat addon-catalog.json | jq -r --arg name "$addon" 'if .addons[$name] then "\($name) ✓" else "\($name) ✗ NOT FOUND" end'
done < /tmp/my-addon-list.txt
```

## Common Addon Selections

### Essential UI Pack
```
WeakAuras2      - Custom display framework
ElvUI          - Complete UI overhaul (if in catalog)
Masque         - Button skinning
Baganator      - Bag overhaul
SavedInstances - Lockout tracking
```

### Raiding Pack
```
DeadlyBossMods - Boss encounter helper
WeakAuras2     - Custom alerts/displays
Cell           - Raid frames
Details        - DPS meter (if in catalog)
```

### Classic Leveling Pack
```
Questie        - Quest helper
Guidelime      - Leveling guide
ClassicCastbars - Enemy castbars
AtlasLootClassic - Loot information
```

### Auction House Pack
```
Auctionator    - AH enhancement
TradeSkillMaster - Advanced AH (if in catalog)
```

## Next Steps (Phase 3)

Once Phase 3 installation system is built, you'll be able to:

```powershell
# Search and install
Search-WowAddons -Query "bag"
Install-WowAddon -Name "AdiBags"

# Install from list
Get-Content my-addon-list.txt | Install-WowAddon

# Install with dependencies
Install-WowAddon -Name "WeakAuras2" -WithDependencies

# Preview before installing
Install-WowAddon -Name "DeadlyBossMods" -WhatIf
```

## Bookmark These Commands

```bash
# Quick browse (alias suggestions for ~/.zshrc or ~/.bashrc)
alias wow-popular='cat ~/code/4JS/addonmanager/addon-catalog.json | jq -r ".addons | to_entries | sort_by(-.value.metadata.stars) | .[:20] | .[] | \"\(.value.metadata.stars)⭐ \(.key)\""'

alias wow-search='f(){ cat ~/code/4JS/addonmanager/addon-catalog.json | jq -r --arg q "$1" ".addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains(\$q)) | \"\(.key) - \(.value.metadata.description[:70])\""; }; f'

# Usage:
# wow-popular
# wow-search "quest"
```
