# Raid iterations

This session landed the Commandos ambush loop (scout → alarm waves → sweep → extract).
Smoke: `SMOKE_SLICE_COMPLETE` + `SMOKE_OK_RAID_LOOP`.

## Landed (this session)

1. Contract doc (`COMMANDOS_RAID.md`)
2. Weapon catalog (knife/pistol/rifle/mg/scout/shotgun/ammo/grenade/mine/decoy)
3. Grid A* pathfinder
4. Raid director (wave index, HUD chips)
5. Map stashes
6. Thrown grenades
7. Placeable mines
8. Decoys (brief distract)
9. Operator inventory + apply_weapon
10. Click-to-move
11. Insert-cell spawn (squad on the map)
12. Pickup on walk
13. Typed corpse drops
14. Sweep phase
15. Multi-wave tables for 6 nights
16. Next-wave + extract
17. Smoke rewrite (pickup, knife leak, 6-night raids)
18. Tutorial / title / README copy
19. Op-card inventory line
20. Touch HUD hint
21. Hold-fire re-arm on later waves
22. Sweep vacuum helper for remaining piles
23. Alarm CTA 拉警报 / 下一波 / 撤离
24. Phase chip 搜刮/警报/打扫
25. Fail still escape/wipe/abort
26. Cover still protects
27. Legacy tripwire kept as fallback mine
28. Roles still bias move speed
29. Observation ring uses kit range
30. Campaign kicker copy

## Backlog toward 100 (playable polish, not a second game)

31. Search time on crates (0.4s channel)
32. Body-carry / hide corpse (presentation)
33. Knife lunge FX
34. Grenade bounce + cook bar
35. Mine placement ghost
36. Decoy actually reroutes one runner one cell
37. Noise meter if you sprint
38. Per-weapon muzzle styles
39. Ammo type per gun (no MG ammo in a pistol)
40. Swap gun vs drop gun on the ground
41. Transfer item between ops
42. Yard teaching: first crate ping
43. Warehouse: wave-2 barrel reminder
44. Pump: door still taught between waves
45. Railcut: ammo warning before wave 2
46. Depot: mine crate is the fourth man
47. Radio: decoy vs echo hall
48. Sweep music bed
49. Footstep ticks
50. Pickup sting per kind
51. Wave siren distinct from first alarm
52. Extract letterbox
53. Fail copy: “wave N leaked”
54. Intel ghosts per wave
55. Last-plan restore keeps facing not guns (already) — show that
56. Touch: move joystick
57. Touch: throw button
58. Gamepad
59. Difficulty: fewer crates
60. Perfect-night star if no HP lost
61. Shotgun yard crate
62. Pistol as fallback after dry gun
63. MG slow-turn
64. Scout silent knife bonus
65. Friendly-fire grenade tutorial
66. Don’t auto-snap cover while walking past
67. Path ghost fade
68. Occupancy: two ops can’t share a cell
69. Enemy drop table per night
70. Echo kit drops radio parts (flavor)
71. Sweep HP drip +10
72. Wave preview ghosts only for next wave
73. Alarm disabled until one firearm looted (soft)
74. Checklist: guns / mines / covers
75. Briefing: “loot then hold”
76. Journal stamps per wave
77. Credits mention sweep
78. Android throw buttons
79. Perf: stash cap
80. Headless probe: grenade kill
81. Headless probe: decoy pause
82. Headless probe: mine inventory
83. Move speed while carrying loot pile (flavor)
84. Facing lock while in cover until A/D
85. Camera follow selected op
86. Double-tap cover to face route
87. Minimap dots for crates
88. Colorblind crate icons
89. VO barks: 有匣 / 雷好了 / 下一波
90. Slow-mo last enemy of a wave
91. Extract requires walking to south mouth (optional hard mode)
92. Seeded drop variance
93. Save inventory mid-night (checkpoint)
94. Photo mode
95. Speedrun timer
96. Accessibility: hold-to-move
97. Localization keys
98. Balance pass ammo counts
99. Human playtest notes
100. Playtest APK re-export

Items 31–100 are the remaining path to “做好”. Core loop 1–30 is playable and smokable.
