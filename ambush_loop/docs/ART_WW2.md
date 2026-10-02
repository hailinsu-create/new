# WWII night-raid art bible

Commandos ambush loop. Original procedural art (polygons, palettes, WAV).
No other-game textures. No neon. No modern polymer guns.

## Tone

North-west Europe night raid: olive drab, khaki wool, mud, rust, steel, cordite.
Moon is paper-white/green, warehouse is sodium, depot is diesel orange.
Operators read as wool webbing. Hostiles read as feldgrau + crimson armband.

## Palette (`scripts/art/ww2_palette.gd`)

| Token | Use |
| --- | --- |
| wool / olive drab / khaki | operators |
| feldgrau | patrol / echo |
| rust-brown | flank runners |
| mud / steel / brass | ground, guns, HUD rails |
| sodium / moonlight | night grade |

## Weapons

Class ids stay for raid smoke: `knife` `pistol` `rifle` `mg` `scout` `shotgun` (+ `smg`).
WWII models sit under those families with real cadence, recoil, mag, muzzle, sfx, loot weight.

See `scripts/raid/weapon_catalog.gd` and `scripts/art/weapon_art.gd`.
Probe: `godot --headless --path ambush_loop -s res://scripts/art_weapon_probe.gd`

Class ids (`rifle`/`mg`/`scout`/`pistol`/`shotgun`) keep raid smoke. Models (Kar98k, MP40, MG42, …) swap cadence, mag, recoil, muzzle, sfx, silhouette, and loot weight.

Counting: one git commit after play freeze `f5e16ae` = one art round. Target 100. HUD icons, dropped-gun stamps, bolt-cycle pose, MG heat, and per-night landmarks are presentation only.

## Do not

- Live2D / side window
- Modern assault-rifle skins
- Copying other games' sprites
