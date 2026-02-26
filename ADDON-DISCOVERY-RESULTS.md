# WoW Addon GitHub Repository Discovery Results

**Date:** 2026-02-14  
**Total Addons:** 11  
**Found on GitHub:** 10/11 (91%)  
**CurseForge Only:** 1/11 (9%)

## ✅ Successfully Mapped (10 addons)

### 1. !BugGrabber
- **GitHub:** https://github.com/funkydude/BugSack
- **Author:** Funkeh (funkydude)
- **Status:** Official repo, active
- **Notes:** Same repo contains both BugGrabber and BugSack

### 2. AbilityTimeline
- **GitHub:** https://github.com/Jods-GH/AbilityTimeline
- **Author:** Jods (Jods-GH)
- **Status:** Official repo, active
- **Notes:** Username differs from .toc (Jods vs Jods-GH)

### 3. BetterBlizzFrames
- **GitHub:** https://github.com/Bodify/BetterBlizzFrames
- **Author:** Bodify
- **Status:** Official repo, active
- **Notes:** Found official source (not mirror)

### 4. BtWQuestsDragonflight
- **GitHub:** https://github.com/Breeni/BtWQuestsDragonflight
- **Author:** Breen (Breeni)
- **Status:** Official repo, active
- **Branch:** mainline

### 5. BtWQuestsMidnightPrologue
- **GitHub:** https://github.com/Breeni/BtWQuestsMidnightPrologue
- **Author:** Breen (Breeni)
- **Status:** Official repo, active
- **Branch:** mainline

### 6. BtWQuestsTheWarWithin
- **GitHub:** https://github.com/Breeni/BtWQuestsTheWarWithin
- **Author:** Breen (Breeni)
- **Status:** Official repo, active
- **Branch:** mainline

### 7. BugSack
- **GitHub:** https://github.com/funkydude/BugSack
- **Author:** Funkeh (funkydude)
- **Status:** Official repo, active
- **Notes:** 43 stars, well-maintained

### 8. TeleportMenu
- **GitHub:** https://github.com/Justw8/TeleportMenu
- **Author:** Justwait (Justw8)
- **Status:** Official repo, active
- **Notes:** Username differs from .toc (Justwait vs Justw8)

### 9. WaypointUI
- **GitHub:** https://github.com/Adaptvx/Waypoint-UI
- **Author:** AdaptiveX (Adaptvx)
- **Status:** Official repo, active
- **Notes:** Username differs from .toc (AdaptiveX vs Adaptvx)

### 10. ZamestoTV_PrePath
- **GitHub:** https://github.com/Hubbotu/Midnight-Twilight-Ascension-Pre-Patch
- **Author:** ZamestoTV (mirrored by Hubbotu)
- **Status:** Mirror repo (original author has no GitHub)
- **Notes:** Folder name: ZamestoTV_PrePath. Hubbotu mirrors all ZamestoTV addons (13 repos)

## ❌ Not on GitHub (1 addon)

### BtWQuests (Core)
- **GitHub:** None - CurseForge only
- **Author:** Breen (Breeni)
- **CurseForge ID:** btw-quests
- **Notes:** Core addon distributed only via CurseForge. Expansion modules (Dragonflight, War Within, etc.) are on GitHub. User has the core addon installed locally.

## Discovery Methods Used

1. **Direct GitHub search** - Primary method
2. **Author username search** - Found repos by known authors
3. **User profile exploration** - Found all Breeni's BtWQuests modules
4. **Mirror repo discovery** - Found Hubbotu mirrors ZamestoTV addons
5. **Code search** - Searched for addon names in Lua code
6. **Local filesystem analysis** - Verified addon folders exist

## Username Mapping

| .toc Author | GitHub Username | Notes |
|-------------|-----------------|-------|
| Funkeh | funkydude | Consistent |
| Jods | Jods-GH | Added "-GH" |
| Bodify | Bodify | Consistent |
| Breen | Breeni | Changed to "Breeni" |
| Justwait | Justw8 | Shortened |
| AdaptiveX | Adaptvx | Shortened |
| ZamestoTV | Hubbotu | No official repo, mirrored |

## Related Discoveries

While searching, found additional Breeni repos not currently installed:
- BtWLoadouts (7 stars)
- BtWTodo (5 stars)
- BtWQuestsShadowlands
- BtWQuestsLegion
- BtWQuestsDragonflightPrologue
- BtWQuestsTheWarWithinPrologue
- BtWRacingLeaderboard

And 13 ZamestoTV addons mirrored by Hubbotu:
- ZamestoTV-Horrific-Vision-Helper
- ZamestoTV-Seperator
- ZamestoTV-Heroism
- ZamestoTV_Teleport
- ZamestoTV-Contract-Missing
- ZamestoTV-Community-Feast
- ZamestoTV-Dungeon-Pass
- ZamestoTV-Zaralek-Caverns-Events-Tracker
- ZamestoTV-Solo-Gold-Farm
- ZamestoTV-Delves-All-Sturdy-Chest
- ZamestoTV-Easy-World-Quests-Dreaming-in-the-Dream
- ZamestoTV-Remix-Mists-of-Pandaria
- Zamesto-TV-Call-to-Arms

## Phase 2 Readiness

All data needed for Phase 2 implementation is now in `addon-repos.json`:
- ✅ Repository owner/name/branch for all GitHub-hosted addons
- ✅ Installed versions from addons.json
- ✅ Update tracking flags
- ✅ Download patterns (asset matching rules)
- ✅ Install paths

Ready to implement:
1. Check-WowAddonUpdates (compare versions)
2. Update-WowAddon (download and install)
3. Update-AllWowAddons (batch updates)
4. Watch-WowAddonUpdates (notification system)
