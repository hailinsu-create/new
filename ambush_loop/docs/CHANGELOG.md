# Changelog

## 0.4.0 — Commandos 2 kit (weapons / backpack / auto nade)

Sideload APK: `dist/AmbushLoop-v0.4.0-commandos2-kit.apk`  
Release tag: `v0.4.0-commandos2-kit`

Mechanism squeeze, not a new campaign. RAID is still SCOUT → ALERT → SWEEP.

### Play
- Firearm kit is **10 named WWII guns**: 5 families × (Allied 1 + Axis 1). No G43 / SVT / PPS / Webley / drilling / 28-model atlas.
- Per-operator **6-slot backpack**. Pickup goes in the pack; first gun auto-equips; later guns wait in the pack. I / 背包 to swap, pass, or drop. Full pack refuses loot.
- Grenades **auto-throw in ALERT** (cone or a SCOUT 雷点). Cooldown 3.6s, skips friendly-fire circle. G during scout places/clears the mark.
- Cinema still **警报中 · 第N/M波**. No 锁死观战.

### Android
- `versionName` 0.4.0 / `versionCode` 4 (`com.ambushloop.game`).

### How to tell you have this build
1. Title stamp **v0.4.0 COMMANDOS/WW2**.
2. Yard crates: **Kar98k / MG42 / 汤姆逊 / M1911 / 卢格** — not G43, not 钻枪.
3. I opens a 6-slot pack. Pull alarm: nades fly on their own if an enemy enters the cone/雷点.

## 0.3.1 — Commandos / WW2 deepen (playtest)

Sideload APK: `dist/AmbushLoop-v0.3.1-commandos-ww2-playtest.apk`  
Release tag: `v0.3.1-commandos-ww2`

Polish on the 0.3.0 raid loop: HUD copy, named crates every night, walk/loot/touch, distinct gunshots.

### Play
- Alert cinema reads **警报中 · 第N/M波** (win: **封锁成功**). No leftover 锁死观战.
- Yard rifle crate is **Kar98k**; class crates resolve to a stable WWII model per night. Yard 9/9 crates spawn (m1911 / shotgun walkable).
- Knife-force leak fail card teaches **先搜枪**. Win flash does not leak into the next night.
- Touch alarm button matches desktop: 需枪 / 强拉警报 / 拉警报 / 下一波警报 / 撤离封锁.
- Faster SCOUT walk, crate-cell click snap, bigger loot radius. Named-gun board during scout.

### Audio / art
- Distinct PCM: bolt clack, Garand ping, MG42 5-round burst, pistol, shotgun.
- Larger crate gun stamps and tags.

### Android
- `versionName` 0.3.1 / `versionCode` 3 (`com.ambushloop.game`).

### How to tell you have this build
1. Title stamp **v0.3.1 COMMANDOS/WW2**.
2. Yard crate tag **Kar98k** (not generic 步枪).
3. Pull alarm: top bar **警报中 · 第1/2波**, not 锁死观战.

## 0.3.0 — Commandos / WW2 playtest

Sideload APK: `dist/AmbushLoop-v0.3.0-commandos-ww2-playtest.apk`  
Release tag: `v0.3.0-commandos-ww2`

This is the Commandos raid loop + WWII weapon models, not the 0.2.0 locked-watch friend pack.

### Play
- SCOUT → ALERT → SWEEP: walk and loot crates, pull alarm, sweep between waves, extract after the last wave.
- Operators spawn with knives. Stand still on a crate ~0.4s to open. Typed ammo. Pass gear with T. Alarm gated until someone loots a firearm.
- 28 WWII firearm models (Kar98k, MP40, MG42, M1 Garand, …) with cadence, mag, recoil, muzzle, sfx, loot weight.
- Title and pause overlay show `v0.3.0 · COMMANDOS / WW2` so a sideload is identifiable.

### Android
- `versionName` 0.3.0 / `versionCode` 2 (`com.ambushloop.game`).
- Debug-signed arm64 landscape playtest. Godot 4.7.2.

### How to tell you have this build
1. Title stamp reads **v0.3.0 COMMANDOS/WW2** (not just “朋友包 · 六夜”).
2. Yard: walk an operator onto a crate; gun stamp can read **Kar98k**.
3. After a wave, phase is **打扫 / SWEEP**, not a frozen spectator lock.

## 0.2.0 — locked-watch friend pack

GitHub release `ambush-loop-playtest-0.2.0` / `AmbushLoop-playtest.apk`.  
Merged to `main` at `82b91dc`. Alarm-watch vertical slice only. No raid director, no crate search, no 28 weapon models.
