MONSTRONOMIKA — GODOT 4.7 MVP / BUILD 3

Open this folder in Godot 4.7 and run project.godot.

WHAT IS IN THIS BUILD
- Main Battle screen with 3 farming locations.
- Manual tap + automatic hero DPS.
- Essence + Dark Essence economy.
- Packs: 500 / 900 / 1300 Essence.
- Dark Pack: 20 Dark Essence, no Common creatures.
- Pack opening modal with 1–3 reveals.
- Creature collection with rarity + duplicate progression.
- Boss cards can also drop from packs and enter the Boss Archive.
- 3 heroes, unlocks, upgrades and additive team DPS.
- Offline Essence income (capped at 8 hours).
- Collection screen with rarity filters.
- Heroes screen.
- Local mock Player Market screen (real multiplayer market is a backend feature later).
- Boss / creature / hero art loaded by stable ID with automatic placeholders.
- Local save to user://monstronomika_save.json.

ART ARCHITECTURE

Put your 1:1 square images here:

res://art/bosses/
res://art/creatures/
res://art/heroes/

The game checks PNG, WEBP, JPG and JPEG automatically. The filename MUST match the internal ID.

BOSS EXAMPLES
res://art/bosses/ash_colossus_boss.png
res://art/bosses/bone_tyrant_boss.png
res://art/bosses/cinder_beast_boss.png
res://art/bosses/swamp_devourer_boss.png
res://art/bosses/plague_saint_boss.png
res://art/bosses/mire_queen_boss.png
res://art/bosses/abyssal_warden_boss.png
res://art/bosses/void_abomination_boss.png
res://art/bosses/hollow_king_boss.png

CREATURE EXAMPLES
res://art/creatures/bone_tyrant.png
res://art/creatures/swamp_devourer.png
res://art/creatures/cinder_beast.png
res://art/creatures/ash_colossus.png
res://art/creatures/plague_saint.png
res://art/creatures/mire_queen.png
res://art/creatures/void_reaper.png
res://art/creatures/abyssal_warden.png
res://art/creatures/star_eater.png
res://art/creatures/blood_seraph.png
res://art/creatures/iron_widow.png
res://art/creatures/sunless_beast.png

HERO EXAMPLES
res://art/heroes/hunter.png
res://art/heroes/warlock.png
res://art/heroes/executioner.png

You do NOT need to edit main.gd just to replace art. Drop files using these IDs and the game picks them up.

NOTE
The current boss / creature data are placeholders for design iteration. We will replace names, IDs, rarity weights, buffs and pack pools once your real archive is imported.
Marketplace is local-mock only. Server authority will be added later for currency, inventory, player market and global-unique Legendary ownership.
