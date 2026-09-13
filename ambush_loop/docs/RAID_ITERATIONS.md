# Raid iterations

Commandos ambush loop (scout → alarm waves → sweep → extract).
Smoke: `SMOKE_SLICE_COMPLETE` + `SMOKE_OK_RAID_LOOP`.

## Landed 1–41 (previous)

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
31. Occupancy: two ops do not share a destination cell
32. Camera follow while walking
33. Title bar shows 波 N/M
34. Touch sweep row
35. Payoff barks loot/sweep/wave
36. Tutorial nights drop “警报后不能微操”
37. Yard must-bring is loot-then-hold
38. Launch-bar tagline
39. Scene CTA 拉警报 / 走路
40. Occupancy smoke probe
41. Depot tut still names 2.2s tripwire

## Landed 42–100 (this session)

42. Crate search channel 0.4s (stand still; lid opens). Smoke: `SMOKE_OK_CRATE_SEARCH`
43. Ammo is per-gun. MG rounds sit in a pool, never load a pistol mag. `SMOKE_OK_AMMO_TYPES`
44. T / 触控「递装」passes gun/nade/mine/decoy to the nearest teammate. `SMOKE_OK_TRANSFER`
45. Alarm soft gate: first Space with knives warns 需枪; second press force-pulls. `SMOKE_OK_ALARM_GATE`
46. Touch 手雷 on scout/sweep and during alert (throw along facing)
47. Fail card: **第N波漏网：** keeps 漏网：/侧翼/敌/秒 so old fail-card smoke still matches
48. Decoy peels one cell toward the pebble, then resumes the authored route. `SMOKE_OK_DECOY_REROUTE`
49. H drags a corpse pile (move speed ×0.62); H again drops it
50. Mine ghost says 埋雷 when the selected op has inventory mines, else 绊索
51. Knife lunge slash FX on melee hits
52. Pickup sting by kind (guns loot, nades/mines trip, decoy ui)
53. Sweep drips +10 HP to living ops
54. Walking past a cover pad no longer auto-snaps; only stopping on the pad cell mounts
55. Intel chip prints 匣N 枪有/无 and the night clock
56. First firearm crate pings (院子 flashes 先开这匣)
57. Warehouse tut: G is grenade; 弹包 is the button; wave-2 barrel reminder
58. Pump tut: decide the door after wave-1 sweep
59. Railcut tut: ammo warning before the east corridor wave
60. Depot tut: mine crate is the fourth man (still names 2.2s 绊索)
61. Radio tut: decoy can tug the echo runner one cell
62. Yard shotgun crate + pistol crate; dry mag falls back to pooled pistol
63. MG rotate_by capped at 8° per tick (slow traverse)
64. Scout knife deals ×1.25
65. Pistol fallback after a dry primary if pistol ammo is pooled
66. Muzzle style follows the gun (mg/scout/shotgun/pistol), not only role
67. Move-path ghost fades after half a second
68. Spawn ghosts show current wave + next wave only (yard still 3 ghosts)
69. Per-night enemy drop tables
70. Echo kit drops 电台零件 → decoy
71. Drop table seeded by leaker/enemy id
72. Grenade bounces once then cooks (pin heats)
73. Hauling a corpse ticks footstep ui
74. Wave 2+ uses `alarm_stinger` instead of the first-alarm cue
75. Sweep plays tension bed; extract shows letterbox
76. Last-plan restore copy: 朝向已恢复，枪要重搜
77. Carry speed while hauling
78. Player double-tap cover faces the next authored route (smoke announce=false keeps facing)
79. Win star ★ 无人受伤 if nobody took return-fire/friendly nade
80. Speedrun clock on the scout intel chip
81. Howto/yard page: 先搜匣再埋伏; G is grenade; T/H listed
82. Journal rows stamp 波 count
83. Credits recap names 搜刮 / 警报 / 打扫
84. GameSettings.few_crates skips ammo/pistol crates (off by default)
85. `RaidLoc` Chinese key table. `SMOKE_OK_LOC`
86. Colorblind crate silhouettes (shape + 中文 tag, not hue alone)
87. Headless grenade kill probe. `SMOKE_OK_GRENADE_KILL`
88. Headless decoy pause probe. `SMOKE_OK_DECOY_PAUSE`
89. Headless mine inventory probe. `SMOKE_OK_MINE_INV`
90. Touch 诱饵 / 递装 on the scout row; 手雷 on the alert row
91. GameSettings.hold_to_move (hold LMB to repath)
92. Stash node cap 12
93. Balance: night-specific ammo/nade/mine drops, warehouse decoy crate
94. VO barks 有匣 / 雷好了
95. Last-runner bark already in; win letterbox on extract
96. Fail records `_wave_fail_index` so the card names the leaking wave
97. Intel ghosts still draw; restore hint no longer claims guns came back
98. Human playtest notes: `docs/RAID_PLAYTEST.md`
99. Occupancy + camera follow still in (31/32); raid contract still smokes both
100. Playtest APK re-export attempted if the Android SDK is on the machine (non-blocking)

## Landed 101–112 (v0.3.1)

101. Cinema banner `警报中 · 第N/M波` (WON: `封锁成功`). No `锁死观战`. `SMOKE_OK_CINEMA`
102. Class crates resolve to stable named WWII models per night (yard rifle = Kar98k). `SMOKE_OK_NAMED_CRATES` / `SMOKE_OK_PICKUP kar98k`
103. Blocked crate cells snap to nearest walkable; yard shotgun/m1911 and railcut mine authored onto open cells. Yard 9/9.
104. Fail card on knife-force leak teaches `先搜匣拿到枪`. `SMOKE_OK_KNIFE_FAIL_COPY`
105. Win flash cleared on next-night setup. `SMOKE_OK_FLASH_CLEAR`
106. Touch alarm CTA tracks 需枪 / 强拉 / 拉警报 / 下一波 / 撤离. `SMOKE_OK_ALARM_CTA`
107. SCOUT walk ~20% faster; crate snap 1 cell; search radius 44px; loot range 56px
108. Stash board lists named guns during SCOUT
109. Per-model gunshots: bolt clack, Garand ping, MG42 5-burst, pistol, shotgun. `SMOKE_OK_SFX_MODELS`
110. Howto / help / main.tscn leftover 锁死 copy cleared
111. Version 0.3.1 / versionCode 3
112. Independent reeval dump `eval_dump_v031.gd`

## Landed 113–124 (v0.4.0 Commandos 2 kit)

113. Weapon catalog squeezed to 10 named guns (5 families × Allied/Axis). `SMOKE_OK_WEAPON_MODELS n=10`
114. Banned tail (G43, SVT, PPS, Webley, drilling, …) gone from loot/HUD/crates
115. Per-operator 6-slot backpack; pickup / equip / pass / drop. `SMOKE_OK_BACKPACK`
116. Backpack UI (I / 背包). `SMOKE_OK_BACKPACK_UI`
117. SCOUT G places 雷点. `SMOKE_OK_NADE_MARK`
118. ALERT auto-grenade (cone or mark, 3.6s CD, FF skip). `SMOKE_OK_AUTO_GRENADE`
119. Touch 雷点 / 背包 / 自动雷
120. Yard crates: Kar98k, MG42, 汤姆逊, M1911, 卢格
121. Tutorial / howto / RAID contract copy: auto nade, no 锁死观战
122. Version 0.4.0 / versionCode 4
123. Kit contract `docs/COMMANDOS2_KIT.md`
124. Dump `eval_dump_v040.gd` + named APK / release

## How to play now (delta vs 41)

- Knives at insert. Walk onto a crate and **stand 0.4s**.
- **Do not mix ammo.** T to pass a gun or nade.
- Alarm wants a firearm; second press still lets you knife-leak.
- Phone: 雷点 / 背包 / 诱饵 / 递装. Alert bar has 自动雷.
- H drags bodies off the road. Sweep heals 10.
- Fail card: 第N波漏网. Win: extra star if nobody was hit.

## Remaining gaps (not a second game)

- No climb / multi-floor / vehicles (contract cut).
- Alarm still freezes walking (auto fire + auto nade).
- Body drag is presentation + slow; no “spotted corpse” AI.
- Hold-to-move and few-crates are flags, not title toggles.
- Photo mode / mid-night inventory checkpoint / gamepad map not shipped.
