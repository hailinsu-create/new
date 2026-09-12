# Changelog

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
