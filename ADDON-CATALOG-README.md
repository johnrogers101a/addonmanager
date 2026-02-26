# WoW Addon Catalog

Comprehensive catalog of 100 most popular WoW addons available on GitHub, sorted by stars.

## Files

- **`addon-catalog.json`** - Full catalog of 100 top GitHub WoW addons (all available to install)
- **`addon-repos.json`** - Your currently installed addons with repo mappings

## Catalog Statistics

- **Total Addons:** 100
- **Popular (>50 stars):** 39
- **Installed:** 0 (tracked in addon-repos.json)
- **Available:** 100

## Top 15 Most Popular Addons

1. ⭐ 1,419 - **WeakAuras2** - Powerful framework to display customizable graphics
2. ⭐ 1,061 - **Questie** - The WoW Classic quest helper
3. ⭐ 271 - **DeadlyBossMods** - Ultimate encounter helper (DBM)
4. ⭐ 266 - **Auctionator** - Auction house enhancement
5. ⭐ 233 - **oUF** - Unit frame framework
6. ⭐ 212 - **DBM-Warmane** - DBM for Warmane servers
7. ⭐ 173 - **vanilla-wow-addons** - Collection for Vanilla WoW
8. ⭐ 171 - **hero-rotation** - DPS rotation optimization
9. ⭐ 168 - **Guidelime** - Leveling guide with auto-progress
10. ⭐ 162 - **Cell** - Raid frame addon
11. ⭐ 153 - **AdiBags** - Bag organization addon
12. ⭐ 150 - **SavedInstances** - Track instance/raid lockouts
13. ⭐ 128 - **TipTac** - Enhanced tooltips
14. ⭐ 100 - **Ace3** - AddOn development framework
15. ⭐ 87 - **NetherBot** - NPC Bot management tool

## Catalog Structure

```json
{
  "version": "1.0.0",
  "lastUpdated": "2026-02-14T22:18:00Z",
  "totalAddons": 100,
  "stats": {
    "installed": 0,
    "available": 100,
    "popular": 39
  },
  "addons": {
    "AddonName": {
      "github": {
        "owner": "username",
        "repo": "AddonName",
        "fullName": "username/AddonName",
        "branch": "main"
      },
      "metadata": {
        "description": "Addon description",
        "stars": 123,
        "forks": 45,
        "language": "Lua",
        "topics": ["wow", "addon"],
        "url": "https://github.com/...",
        "lastUpdated": "2026-01-01T00:00:00Z"
      },
      "status": {
        "installed": false,
        "installPath": null
      },
      "updateTracking": {
        "enabled": false,
        "checkReleases": true,
        "installedVersion": null,
        "latestVersion": null
      }
    }
  }
}
```

## Usage Examples

### Browse Available Addons

```bash
# List all addons by stars
cat addon-catalog.json | jq -r '.addons | to_entries | sort_by(-.value.metadata.stars) | .[] | "\(.value.metadata.stars) ⭐ \(.key) - \(.value.metadata.description)"'

# Find addons by topic
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.topics | contains(["raid"])) | .key'

# Show addons with >100 stars
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.stars > 100) | "\(.key) (\(.value.metadata.stars) stars)"'
```

### Search for Specific Addons

```bash
# Find bag addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("bag")) | .key'

# Find UI addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("ui")) | .key'

# Find quest addons
cat addon-catalog.json | jq -r '.addons | to_entries | .[] | select(.value.metadata.description | ascii_downcase | contains("quest")) | .key'
```

### Get Addon Details

```bash
# Get full info for an addon
cat addon-catalog.json | jq '.addons["WeakAuras2"]'

# Get GitHub URL for an addon
cat addon-catalog.json | jq -r '.addons["DeadlyBossMods"].metadata.url'

# Get repo owner and name
cat addon-catalog.json | jq -r '.addons["Questie"] | "\(.github.owner)/\(.github.repo)"'
```

## Phase 3: Installation System (Planned)

Future commands will use this catalog:

```powershell
# Search catalog
Search-WowAddons -Query "bag"

# Show addon details
Get-WowAddonInfo -Name "WeakAuras2"

# Install addon from catalog
Install-WowAddon -Name "WeakAuras2"

# Browse categories
Get-WowAddonsByCategory -Category "UI"

# Install multiple addons
Install-WowAddon -Name "DeadlyBossMods", "WeakAuras2", "AdiBags"
```

## Updating the Catalog

To refresh the catalog with latest GitHub data:

```bash
# Re-run the GitHub search and rebuild catalog
# (Implementation in Phase 3)
Update-WowAddonCatalog
```

## Categories

Addons are tagged with topics from GitHub:
- `addon`, `world-of-warcraft`, `wow-addon` - General WoW addons
- `ui`, `interface` - UI modifications
- `raid`, `dungeon`, `combat` - PvE content
- `pvp`, `arena`, `battleground` - PvP content
- `bag`, `inventory` - Inventory management
- `quest`, `leveling` - Questing and leveling
- `auction`, `economy` - Auction house and gold making
- `classic`, `retail`, `wotlk` - Game version specific

## Notes

- Catalog includes top 100 GitHub addons by star count
- All addons have >5 stars (quality filter)
- Lua language primary (with some multi-language repos)
- Last updated: 2026-02-14
- Refresh recommended monthly for new addons
- Some addons may require dependencies (check repo README)
- Classic vs Retail compatibility varies by addon

## Related Files

- `addon-repos.json` - Currently installed addons with tracking
- `ADDON-DISCOVERY-RESULTS.md` - Discovery process documentation
- `PHASE2-PLANNING.md` - Update system design
- `README.md` - Main project documentation
