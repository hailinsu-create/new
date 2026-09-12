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

## Backlog 17–100

17. Kar98k bolt-knob + wood furniture overlay
18. Lee-Enfield magazine box on silhouette
19. M1 Garand en-bloc hump
20. Mosin extra-long barrel vs G43
21. MP40 folding-stock vs Sten side mag
22. Thompson compensator vs PPS-43
23. MG42 vented barrel vs BAR bipod
24. Bren top mag vs DP pan
25. M1911 vs Luger grip angle on HUD icon
26. Scoped Kar98k / Springfield tube
27. Shotgun rib vs Drilling twin pipes
28. Knife fuller, not a grey stick
29. Operator Brodie / wool cap vs Stahlhelm enemies
30. Puttees / ankle wraps
31. Pouches on webbing
32. MG gunner ammo box on pack
33. Scout hood wool, not cyan visor
34. Enemy helmet brim + rain cover
35. Flank runner bread-bag
36. Sneak smock folds
37. Echo radio pack (not phosphor mast only)
38. Corpse dropped-gun silhouette uses the model
39. Loot crate as wooden ammo box + stencil
40. Grenade as Stielhandgranate
41. Mills / Mk2 variants later nights
42. Tellermine dish + fuze
43. Decoy as pebble/tin, not triangle
44. Brass casing eject
45. Spark ticks on steel hits
46. Bullet pock on walls
47. Scorch under grenade
48. Mud footprints behind walk
49. Cordite puff lingering after MG
50. Night-specific key lights (less cyan radio)
51. Yard ruts + horse dung
52. Warehouse oil + pallet grain
53. Pump rust pipes, less teal
54. Railcut coal dust
55. Depot hazard chevrons muted
56. Radio moonlight steel, not phosphor candy
57. Sky: fewer lime stars, more sodium windows
58. Title backdrop wartime courtyard
59. Briefing dossier paper stock
60. Op-card brass pip + gun icon
61. Role glyph khaki, not lime
62. Cover sandbags burlap weave
63. Killzone overlay cordite, not neon
64. Ambush zone chalk, not cyan
65. Trap path as boot prints
66. Spawn ghost feldgrau
67. Intel ghost paper overlay
68. HUD gun name uses model (Kar98k not 步枪 when looted)
69. Ammo pips match mag size
70. Dry-gun mark as open bolt
71. Muzzle smoke blob per family
72. Recoil kick scaled already — add bolt cycling pose
73. Garand ping on empty
74. MG42 barrel glow after burst
75. Shotgun flash wider than SMG
76. Pistol flash short
77. Scout flash tight spark
78. Footstep mud puffs
79. Body drag smear
80. Mine pulse as dull red, not lime
81. Grenade pin brass
82. Crate lid wood grain
83. Six-night wall language: brick / plate / pipe more material
84. Door jamb rust
85. Escape mouth lamplight
86. Pause overlay paper
87. Tutorial chrome khaki
88. Credits wartime type
89. Icon.svg olive/brass
90. Clear color asphalt-mud
91. Power-saving still reads wool vs feldgrau
92. Colorblind: armband + helmet shape, not hue alone
93. Visual dump still captures setup
94. Feel-gate still green
95. Model loot weights per night
96. Rare ZF/Springfield on radio
97. Sten common on pump
98. MG42 rare on railcut
99. Screenshot pass / APK
100. Close-out: HEAD, smoke, model table

Empty docs-only commits stay ≤5.
