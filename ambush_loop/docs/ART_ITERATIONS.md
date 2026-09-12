# Art iterations 1–100

WWII write-real pass on `cursor/commandos-ambush-0641`. Play loop unchanged.
Smoke: `SMOKE_SLICE_COMPLETE` + `SMOKE_OK_RAID_LOOP` + `SMOKE_OK_WEAPON_MODELS`.

## Landed

1. WWII palette module (wool / mud / rust / steel / moonlight)
2. Weapon catalog: class ids kept; 28 WWII models with cadence/recoil/mag/sfx
3. Family ammo pooling (Kar98k eats 步枪弹, MG42 eats 机枪弹)
4. Operator apply_weapon copies model stats into the gun in hand
5. Transfer / receive any firearm id, not only class names
6. Per-model silhouettes (`weapon_art.gd`)
7. Muzzle style/intensity from the catalog
8. Fire cues: bolt / Garand / SMG / MG42 besides role fallback
9. Wool webbing on operators; khaki kit colors
10. Feldgrau hostiles + crimson armband (not neon orange)
11. Night grade from the WWII palette
12. Floor palettes: mud yard, rust warehouse, coal rail, diesel depot
13. HUD NightOps: paper text, brass rail, khaki olive
14. Stash silhouettes by family (incl. SMG)
15. Extra model crates: depot Thompson, radio Springfield + Luger
16. Fast probe `art_weapon_probe.gd` + smoke `_assert_weapon_models`
17. Wool visor, khaki helm, pouches, wood stocks
18. Stielhandgranate / Tellermine / granite decoy
19. Brass casings + mud boot prints
20. Moonlight keys; radio lantern not phosphor candy
21. Wooden ammo boxes, crate grain, burlap, bullet pocks
22. Khaki glyphs, brass buttons, wartime icon
23. Stahlhelm brim, puttees, 98K ZF bulge, steel echo mast
24. Model name on op cards; khaki ambush chalk
25. Rust brick streaks; olive pump/radio walls; Garand ping
26. Radio hall steel wash; pump oil vapour
27. Brass touch rail; paper journal/credits; wartime title dish
28. Rust drum, dropped-gun stamp, bread-bag, MG bipod
29. Moonlight overwatch ring, steel radio dish, brass echo paint
30. Lantern hut, brass motes, steel front sight
31. Paper stars, rail glint, khaki yard pools
32. Thompson drum; MP40/Sten/MG42 crates
33. Olive protect arc
34. Rust tags, paper title moon, oil sheen
35. Olive HP, Enfield mag box, pump vent bars
36. Webley cylinder, Bren top mag, DP pan, M30 twin pipes
37. Steel lighthouse + dish bowls
38. MP38 vs MP40, Springfield/PU scopes, sneak smock
39. Winter-bare yard tree, rust warehouse peak, brick pump stack
40. Pump rust pipes/valves; warehouse oil; rail sodium; radio brass glass

## Backlog 41–100

41. Mills / Mk2 grenade variants on later nights
42. Bolt-cycle pose on Kar98k / Mosin
43. MG42 barrel heat after a burst
44. Cordite puff lingering on MG
45. Spark ticks on steel hits
46. Scorch under grenade
47. Yard ruts + horse dung
48. Railcut coal dust
49. Depot chevrons muted further
50. Echo radio pack (not mast only)
51. Intel ghost paper overlay
52. Trap path as boot prints
53. Ammo pips match mag size
54. Dry-gun as open bolt, not just 空
55. Body drag smear
56. Door jamb rust
57. Escape mouth lamplight
58. Colorblind: helmet shape + armband (already started)
59. Power-saving still reads wool vs feldgrau
60. Visual dump still captures setup
61. Feel-gate still green
62. Model loot weights per night (tables started)
63. Rare ZF crate on radio
64. Screenshot pass
65. Playtest APK re-export
66–99. Further silhouette/VFX/HUD passes
100. Close-out: HEAD, smoke, model table

Empty docs-only commits stay ≤5.
