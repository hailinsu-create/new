# Art iterations 1–100

WWII write-real pass on `cursor/commandos-ambush-0641`. Play loop unchanged.

## Counting

**Round = one git commit after play-loop freeze `f5e16ae`.**

- Slice start / session 0 HEAD: `bfa3557` = round **60**
- This session lands rounds **61–100**
- Docs-only commits in the 100: 3, 40, 49, 58, 100 (≤5)
- Smoke: `SMOKE_SLICE_COMPLETE` + `SMOKE_OK_RAID_LOOP` + `SMOKE_OK_WEAPON_MODELS`

Class ids (`rifle`/`mg`/`scout`/`pistol`/`shotgun`/`smg`) keep raid smoke. Models swap cadence, mag, recoil, muzzle, sfx, silhouette, loot weight.

## Landed 1–60 (prior)

1. WWII models with real cadence, mag, family ammo
2. Wool operators, feldgrau hostiles, mud floors
3. WWII bible and 1–100 backlog
4. Hostile HP bars stay route-red
5. Wool visor, khaki helm, pouches, wood stocks
6. Stielhandgranate, Tellermine dish, granite pebble
7. Brass casings and mud boot prints
8. Moonlight keys; radio lantern not phosphor candy
9. Wooden ammo boxes, crate grain, burlap, bullet pocks
10. Khaki glyphs, brass buttons, wartime icon
11. Stahlhelm brim, puttees, scoped 98K bulge, steel echo mast
12. Model name on cards, khaki ambush chalk, paper pause
13. Rust brick streaks, olive pump/radio walls, Garand ping
14. Radio hall steel wash, pump steam as oil vapour
15. Brass touch rail, paper journal/credits, wartime title dish
16. Rust drum, dropped-gun stamp, bread-bag, MG bipod
17. Moonlight overwatch ring, steel radio dish, brass echo paint
18. Lantern hut, brass motes, steel front sight
19. Paper stars, rail glint, yard moon pools as khaki wash
20. Thompson drum; MP40/Sten/MG42 crates on later nights
21. Olive protect arc
22. Rust tags, blood pocks, paper title moon, oil sheen
23. Olive HP, Enfield mag box, pump vent as oil vapour bars
24. Webley cylinder, Bren top mag, DP pan, M30 twin pipes
25. Steel lighthouse and dish bowls
26. Khaki cover highlight, brass pips, hemp tripwire, paper help
27. MP38 vs MP40, Springfield/PU scopes, sneak smock hem
28. Winter-bare yard tree, rust warehouse peak, brick pump stack
29. Ithaca vs M12, G43 vs SVT; yard M1911 crate; sodium canopy
30. Brass payoff chips, paper tutorial dim, khaki cover shield
31. Brass route traces, khaki sneak chip, winter canopy
32. Pump rust pipes/valves; warehouse oil; rail sodium; radio brass glass
33. Warehouse oil stain, rubber hose, rust gauge, rail sodium lamps
34. Brass lighthouse glass, steel dishes, lamplight floor stripes
35. Grenade scorch, steel-spark helper, brass scout tracer
36. Brass phase chip and echo route chip
37. Steel radio mast pulse, Morse hut lamplight, spare dish rust
38. Cordite smoke blob behind the muzzle
39. Mud prints every third stride
40. Note class ids vs WWII models in the bible
41. Scout leather boots
42. Canvas packs, extra bolt-gun recoil kick
43. Keep ambush icon tokens; sneak boots leather
44. Webbing gear as canvas khaki
45. MG42 heat shimmer on the hottest bursts
46. Paper intel / olive sneak / brass echo chips
47. Radio echo-hall lamplight ticks
48. M1 Garand en-bloc hump; scout cape as brown wool
49. Docs: land 41–46
50. Playtest APK re-export
51. Kar98k bolt knob; knife fuller
52. Paper op-card chrome
53. Khaki cover-arc edges
54. Trip snap as cordite
55. Luger vs 1911; PPS-43 vs MP40
56. Brass dossier rails
57. Stained-wood crate lids
58. Docs: land 47–54
59. Echo-soon boom as brass
60. Yard moon as paper-white, not lime wash

## Landed 61–100 (this session)

61. Kar98k/Mosin bolt-cycle pose after the shot
62. MG42 barrel heat glow after a burst
63. Mud drag smear behind a dropped corpse
64. Wagon ruts and horse dung on the west garden
65. Per-model gun icons instead of family blobs
66. Dropped guns lie on the mud as steel silhouettes
67. Mills and Mk2 grenades on later nights
68. Shotgun petals, pistol stub, MG cordite linger
69. Steel spark ticks on a live hit
70. Dirt clod and ash under a grenade scorch
71. Coal dust, muted chevrons, rust jambs, escape lamp
72. Echo radio pack and strap, not mast only
73. Paper wash under the leaked intel path
74. Boot prints along the second-layer trap route
75. Brass ammo pips match the mag in hand
76. Dry rifle holds the bolt open
77. Stahlhelm brim and puttees on hostiles
78. Deeper yard grade; saving still splits wool from feldgrau
79. MG42 jacket vs MG34, G43 mag vs SVT barrel, P38 slide
80. ZF scope tube, Thompson drum, BAR mag, dirty cape hem
81. Extra moonlight pools on the yard ruts and well
82. Tellermine pressure plate and spider springs
83. Crate gun stamp uses the model icon
84. Brass casings sized to caliber
85. Readable gun stamp on operator cards
86. Sodium cages, pump oil vapour, lighthouse panes
87. Lingering bolt spark on rifle shots
88. Ithaca receiver vs M12 tube; Sten mag longer than PPS
89. Mud lip under the sandbag crate
90. Granite fleck on the decoy pebble
91. Kill burst shards as cordite, not lime gold
92. Horseshoe prints and a rare ZF crate
93. MG ammo belt and leather glove on the gun arm
94. Warehouse aisle pools and a pump hose puddle
95. Dirt hem on the sneak smock
96. Echo hall wash as lamplight brass, not ice cyan
97. Dry-gun 空 mark as brass
98. Role glyph wool as khaki drab
99. Trap boot-print parse fix (`left` shadow)
100. Close-out: HEAD, smoke, model table, playtest APK

## Model table (28, unchanged ids)

| Family | Models |
| --- | --- |
| rifle | Kar98k, Lee-Enfield, M1 Garand, Mosin, G43, SVT-40 |
| smg | MP40, Sten, Thompson, PPS-43, MP38 |
| mg | MG42, MG34, BAR, Bren, DP-28 |
| pistol | M1911, Luger, P38, Webley, TT-33 |
| scout | Kar98k ZF, Springfield, Enfield T, Mosin PU |
| shotgun | Winchester M12, Ithaca 37, M30 Drilling |

Throwables: Stielhandgranate (yard/warehouse), Mills (pump/railcut), Mk2 (depot/radio). Tellermine. Granite decoy.

## Probe

`godot --headless --path ambush_loop -s res://scripts/art_weapon_probe.gd` → `SMOKE_OK_WEAPON_MODELS n=28`
