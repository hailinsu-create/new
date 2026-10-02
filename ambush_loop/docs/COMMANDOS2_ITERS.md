# Ambush Loop — Commandos 2 iterations 1–100 (v0.5.0)

Research first, then 100 perceivable commits on `cursor/commandos-ambush-0641` from `17b3c28` / v0.4.0.

RAID is still **SCOUT → ALERT → SWEEP**. Alarm still freezes walking (auto fire + auto nade). This pass adds Commandos 2 *verbs and chrome* on top of the night raid, not a stealth sandbox and not an RTS.

## Research: template vs v0.4.0

**盟军敢死队 2** is point-select one commando, point-to-move, independent backpacks, scavenge, silent setup, then a fight. Tools have personality. It is not a full real-time army RTS.

v0.4.0 already had: click-to-select, click-to-move, 6-slot pack, 10 named guns, auto nades, H-drag corpses, decoys, mines, RAID waves.

Gaps this session closed:

| Template | v0.4.0 | v0.5.0 |
|----------|--------|--------|
| Bottom portraits | Left cards only | Bottom portraits + left cards |
| Skill hotbar | Keys scattered | C/Q/W/Z + 4–8 + touch 匍匐/割喉/口哨/捆绑 |
| Context cursor | Generic click | 开匣 / 搜尸 / 趴下 / 割喉 / 选中 |
| Destination X | Path ghost faded | Persistent dest X, path dots |
| Double-click run | Hold-to-move flag | Double-click sprint, Shift walk |
| Stance | Cover pads only | Stand / crouch / sprint + stance glyph |
| Enemy vision cones | Player fire cones | Sentry yellow cones in SCOUT; red in ALERT |
| Patrols during scout | Ghosts only | Live 岗哨 on the main route (does **not** auto-pull RAID) |
| ? / ! | None | Suspicious / alert balloons, sleep Z |
| Hear rings | Footstep ui cue | Expanding rings; whistle peels one cell |
| Shadows / bushes | None | Crouch-in-shadow hides from cones |
| Mini-map | None | Click-to-pan + click-to-select |
| Camera | Follow while walking | Wheel zoom, arrows, edge pan, middle-drag, F1/F2 |
| Examine | Crate tags | Hover flavor (Kar98k, 岗哨, class crates) |
| Audio personality | Gun PCM | Foot, whistle, knife, crate lid, body drop, stealth bed |
| Teaching | RAID verbs | Portraits, crouch, Q skills, 岗哨黄锥 |

Deliberately still cut (contract): climb / multi-floor / vehicles / disguise / FOW rewrite / free walk during ALERT.

## Landed 1–100

1. HUD glyphs for crouch / knife / whistle / binocs
2. Per-role skill catalog, hotkeys C/Q/W/Z
3. Destination X flag until arrival
4. Sentry ? / ! / sleep-Z balloons
5. Expanding hear-rings
6. Context cursor 开匣/搜尸/趴下/割喉
7. Bottom portrait strip
8. Skill hotbar with cooldown pips
9. Click-to-pan minimap
10. Bush and shadow tiles (crouch hides)
11. Scout-phase patrol sentry with LOS cone
12. C2 director (portraits, skills, sentries, dest, cursor)
13. Stand / crouch / sprint + noise levels
14. Enemy LOS cones in ALERT (green patrol / red alert)
15. SFX: foot, whistle, knife, crate lid, body drop, select, stealth bed
16. Wire director: double-click sprint, wheel zoom, Q skills
17. Touch 匍匐 / 割喉 / 口哨
18. Yard tutorial names portraits, crouch, Q
19. Howto lists C/Q/W/Z, double-click, portraits
20. Loc keys crouch/knife/whistle/quiet yard
21. Smoke: sentry, portraits, crouch, KO, enemy cone, SFX
22. Sentry cone edge (yellow / red)
23. Portrait selected pulse; dead = 阵亡
24. Minimap north marker
25. Crouch turns slower; scout quieter; sprint dust; stance glyph
26. Binoculars zoom, KO loot, quiet-yard extra nade, 4–8 skills, examine
27. Crate-lid / body-drop SFX, path dots, Shift-walk, middle-pan
28. Barks: spotted / KO / crouch
29. Backpack crouch stamp + double-click equip hint
30. Pause menu lists C/Q/W/Z and double-click
31. Larger dest X with a north tick
32. Extra yard south-fence bushes
33. Skill buttons print cooldown seconds
34. Enemy cone outline during the wave
35. Loc: binoculars, Shift-walk, examine, shadows
36. Touch 捆绑
37. Credits 点选单兵
38. Left cards stamp 匍 / 奔
39. Later-night tutorials mention sentry cones
40. Examine flavor + stance glyph
41. Close-range knife, faster edge-pan, F2 recage, bush rustle
42. Slower suspicion decay + Stahlhelm brim
43. Phase chip 搜刮潜行; F2; pass-range ring
44. Minimap click selects nearest commando
45. Double-click portrait pans camera
46. Selection ring rotates (marching ants)
47. Longer whistle, quieter footsteps, wetter knife
48. Skill-bar border uses role kit color
49. Alert bang pulses a red halo
50. Director HUD chip 搜刮潜行
51. Title tagline 点选单兵 · 搜刮潜行
52. Crouch hint names bushes
53. **Mid bump v0.4.5 / versionCode 5**
54. Extra bushes on warehouse / pump / railcut / depot / radio
55. Crouch searches crates a beat slower
56. First-aid burst ring + heal in the hint
57. Sentry tag 岗哨
58. Larger minimap
59. Larger portraits
60. Loc: F2, pass-range, KO loot, quiet nade
61. Title stamp v0.4.5; phone howto names crouch
62. Howto F1/F2, middle-pan, Shift
63. Pause keys mention F2
64. Credits 岗哨黄锥
65. Yard tutorial: portraits, crouch, backstab
66. Touch hint 匍匐躲岗
67. Thicker hear-rings
68. Dest X tinted with role kit
69. Binoculars raise observation rings
70. Smoke: touch crouch, sprint speed, quiet-yard loc
71. Larger whistle glyph
72. Bigger context-cursor caption
73. Raise ?/! over the helmet
74. Brighter patrol cones
75. Knife cooldown 0.9s
76. Sweep help names 包扎(Z)
77. Larger minimap crate diamonds
78. Examine lines for class crates
79. Brighter olive highlight
80. Fatter skill buttons
81. Faster double-click sprint
82. Sentry sight 132px
83. Portraits sit higher above the bar
84. APK assert requires C2 director / sentry / portraits / skill bar / minimap
85. Launch-bar D11 names portraits + sentry cones
86. Bind hint: Z 靠近再用
87. Alert help: 走位等打扫
88. Kit contract v0.5.0 (this file’s sister `COMMANDOS2_KIT.md`)
89. This iteration log 1–100
90. Changelog 0.5.0
91. ANDROID sideload copy
92. README APK pointer
93. dist/ README named 0.5.0 APK
94. RAID_ITERATIONS 125–224 pointer
95. COMMANDOS_RAID input table: C/Q/W/Z
96. **v0.5.0 / versionCode 6**
97. Smoke version 0.5.0 + extra C2 asserts stay
98. Named APK `AmbushLoop-v0.5.0-commandos2-kit.apk`
99. GitHub release `v0.5.0-commandos2-kit`
100. Playtest recap pointer / kit smoke list

## How to tell you have v0.5.0

1. Title stamp **v0.5.0 COMMANDOS/WW2**, tagline **点选单兵 · 搜刮潜行**.
2. Bottom three portraits. I still opens the 6-slot pack.
3. Yard: a 岗哨 walks the spine with a yellow cone. C crouch in a bush; Q backstab.
4. Pull alarm: cinema **警报中 · 第N/M波**; walking still frozen; auto fire + auto nade.

## Smoke

```
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
```

Must print `SMOKE_GAME_VERSION 0.5.0`, the v0.4.0 kit asserts, plus:

- `SMOKE_OK_SENTRY`
- `SMOKE_OK_PORTRAITS` / `SMOKE_OK_SKILLBAR` / `SMOKE_OK_MINIMAP`
- `SMOKE_OK_CROUCH` / `SMOKE_OK_KO` / `SMOKE_OK_ENEMY_CONE`
- `SMOKE_OK_C2_SFX` / `SMOKE_OK_C2_LOC`
- `SMOKE_OK_TOUCH_CROUCH` / `SMOKE_OK_SPRINT` / `SMOKE_OK_QUIET_LOC`
- `SMOKE_SLICE_COMPLETE` + `SMOKE_OK_RAID_LOOP`
