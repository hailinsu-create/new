# Changelog

## 0.5.30 — Phone feel: west bodies/rings shrink + camera one more step

Sideload APK: `dist/AmbushLoop-v0.5.30-touch-slide.apk`  
Release tag: `v0.5.30-touch-slide`

Same RAID as 0.5.29 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷人影 / 观察环 / 镜头**: dest cells kept from 0.5.25–0.5.29 — lead (7,12), first follower (6,9) three along-file (dx=1, not hugging the west wall), second (5,14). Span 3. No dest-cell stretch. Bodies shrink to ~0.26, observation rings ~0.20, rings offset one more along-file / courtyard step (~68px radial + side stagger, +38px east) so the trio + yellow cone read as three bodies even though they still sit on span-3 cells. Camera pulls to ~0.28. Yellow-cone fade kept.
- **绕箱南走廊**: unchanged from 0.5.26–0.5.29. Full path y14=0 (mid x≈21 included), east overshoot 0, axis_run 0. Far-side bow sits on the y=13 rim (~15px; far-cap constant still 20).
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + dest span 3 + smaller bodies/rings + ring courtyard offset + camera 0.28, compact narrow pack, crate-face axis_run 0, and south-corridor **full path** y≤13. 0530 pack is slim so the suite finishes without a 10-minute cut.

### Android
- `versionName` 0.5.30 / `versionCode` 36 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.30 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: dests still (7,12)/(6,9)/(5,14), span 3. Bodies and observation rings smaller than 0.5.29. Camera a step wider (~0.28). Yellow cone still faded. South-corridor crate arc still y≤13 at x≈21.

## 0.5.29 — Phone feel: west bodies/rings shrink + camera one more step

Sideload APK: `dist/AmbushLoop-v0.5.29-touch-slide.apk`  
Release tag: `v0.5.29-touch-slide`

Same RAID as 0.5.28 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷人影 / 观察环 / 镜头**: dest cells kept from 0.5.25–0.5.28 — lead (7,12), first follower (6,9) three along-file (dx=1, not hugging the west wall), second (5,14). Span 3. No dest-cell stretch. Bodies shrink to ~0.30, observation rings ~0.24, rings offset one more along-file / courtyard step (~60px radial + side stagger, +30px east) so the trio + yellow cone read as three bodies even though they still sit on span-3 cells. Camera pulls to ~0.32. Yellow-cone fade kept.
- **绕箱南走廊**: unchanged from 0.5.26–0.5.28. Full path y14=0 (mid x≈21 included), east overshoot 0, axis_run 0. Far-side bow sits on the y=13 rim (~15px; far-cap constant still 20).
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + dest span 3 + smaller bodies/rings + ring courtyard offset + camera 0.32, compact narrow pack, crate-face axis_run 0, and south-corridor **full path** y≤13.

### Android
- `versionName` 0.5.29 / `versionCode` 35 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.29 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: dests still (7,12)/(6,9)/(5,14), span 3. Bodies and observation rings smaller than 0.5.28. Camera a step wider (~0.32). Yellow cone still faded. South-corridor crate arc still y≤13 at x≈21.

## 0.5.28 — Phone feel: west obs-ring + camera one more step

Sideload APK: `dist/AmbushLoop-v0.5.28-touch-slide.apk`  
Release tag: `v0.5.28-touch-slide`

Same RAID as 0.5.27 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷观察环 / 镜头**: dest cells kept from 0.5.25–0.5.27 — lead (7,12), first follower (6,9) three along-file (dx=1, not hugging the west wall), second (5,14). Span 3. No dest-cell stretch. Observation rings offset one more along-file / courtyard step (~52px radial + side stagger, +22px east) so the trio + yellow cone read as three bodies even though they still sit on span-3 cells. Camera pulls to ~0.34 / body 0.34 / obs 0.28 / yellow-cone fade kept.
- **绕箱南走廊**: unchanged from 0.5.26/0.5.27. Full path y14=0 (mid x≈21 included), east overshoot 0, axis_run 0. Far-side bow sits on the y=13 rim (~15px; far-cap constant still 20).
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + dest span 3 + ring courtyard offset + camera 0.34, compact narrow pack, crate-face axis_run 0, and south-corridor **full path** y≤13.

### Android
- `versionName` 0.5.28 / `versionCode` 34 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.28 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: dests still (7,12)/(6,9)/(5,14), span 3. Observation rings sit further apart along the file / toward the courtyard than 0.5.27. Camera a step wider (~0.34). Yellow cone still faded. South-corridor crate arc still y≤13 at x≈21.

## 0.5.27 — Phone feel: west observation-ring courtyard offset

Sideload APK: `dist/AmbushLoop-v0.5.27-touch-slide.apk`  
Release tag: `v0.5.27-touch-slide`

Same RAID as 0.5.26 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷观察环**: dest cells kept from 0.5.25/0.5.26 — lead (7,12), first follower (6,9) three along-file (dx=1, not hugging the west wall), second (5,14). Span 3. No dest-cell stretch. Observation rings offset further along-file and into the courtyard (~44px radial + side stagger, +14px east) so the trio + yellow cone read as three bodies. Camera 0.36 / body 0.34 / obs 0.28 / yellow-cone fade kept.
- **绕箱南走廊**: unchanged from 0.5.26. Full path y14=0 (mid x≈21 included), east overshoot 0, axis_run 0. Far-side bow sits on the y=13 rim (~15px; far-cap constant still 20).
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + dest span 3 + ring courtyard offset, compact narrow pack, crate-face axis_run 0, and south-corridor **full path** y≤13.

### Android
- `versionName` 0.5.27 / `versionCode` 33 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.27 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: dests still (7,12)/(6,9)/(5,14), span 3. Observation rings sit further apart along the file / toward the courtyard. Yellow cone still faded. South-corridor crate arc still y≤13 at x≈21.

## 0.5.26 — Phone feel: south-corridor full path y=14 gone

Sideload APK: `dist/AmbushLoop-v0.5.26-touch-slide.apk`  
Release tag: `v0.5.26-touch-slide`

Same RAID as 0.5.25 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷落点**: dest cells kept from 0.5.25 — lead (7,12), first follower (6,9) three along-file (dx=1, not hugging the west wall), second (5,14). Span 3. No dest-cell stretch. Camera 0.36 / obs offset / body 0.34 / obs 0.28 / yellow-cone fade kept.
- **绕箱南走廊**: mid-corridor x≈21 y=14 bow samples pulled into y≤13. Full path y14=0 (not only the east end). Far-side bow sits on the y=13 rim (~15px; far-cap constant still 20 so large crate-cluster bows are not flattened). Walkable, axis_run 0, east overshoot 0.
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + dest span 3, compact narrow pack, crate-face axis_run 0, and south-corridor **full path** y≤13.

### Android
- `versionName` 0.5.26 / `versionCode` 32 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.26 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: dests still (7,12)/(6,9)/(5,14), span 3. Yellow cone still faded. South-corridor crate arc no longer kisses y=14 at x≈21.

## 0.5.25 — Phone feel: west dest restagger, south-corridor y=14 gone

Sideload APK: `dist/AmbushLoop-v0.5.25-touch-slide.apk`  
Release tag: `v0.5.25-touch-slide`

Same RAID as 0.5.24 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷落点**: dest cells restaggered so the trio is less sticky. Lead (7,12), first follower (6,9) three along-file (dx=1, not hugging the west wall), second (5,14) two back / two the other way. Span 3. Gameplay cone / ambush / RAID rules unchanged. Camera 0.36 / obs offset / body 0.34 / obs 0.28 / yellow-cone fade kept.
- **绕箱南走廊**: remaining east-end y=14 sample pulled into y≤13. Far-side bow still ~20px, walkable, axis_run 0, east overshoot 0. Large crate-cluster bows not flattened.
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + dest restagger, compact narrow pack, crate-face axis_run 0, and south-corridor y≤13.

### Android
- `versionName` 0.5.25 / `versionCode` 31 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.25 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: first follower stands a cell further along the file than 0.5.24; dests are (7,12)/(6,9)/(5,14). Yellow cone still faded.

## 0.5.24 — Phone feel: west camera/ring offset, south-corridor bow ~20px

Sideload APK: `dist/AmbushLoop-v0.5.24-touch-slide.apk`  
Release tag: `v0.5.24-touch-slide`

Same RAID as 0.5.23 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷再松**: camera pulls to ~0.36 on the trio + yellow cone. Observation rings offset in world space (~36px off the cluster). Follow ring-world side stagger extra. Dest cells / span 2 / first-follower pocket / yellow-cone fade / west wall clearance / body scale 0.34 / obs scale 0.28 unchanged from 0.5.23.
- **绕箱南走廊**: far-side bow cap holds ~20px (was measured ~24px). East-end y=14 dip shallower. Still walkable, axis_run 0, east overshoot 0. Large crate-cluster bows not flattened.
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + first-follower pocket, compact narrow pack, crate-face axis_run 0, and south-corridor far-side cap.

### Android
- `versionName` 0.5.24 / `versionCode` 30 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.24 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: camera pulls further than 0.5.23; dest cells still (7,12)/(6,10)/(5,13). Yellow cone still faded.

## 0.5.23 — Phone feel: smaller west silhouettes, tighter south-corridor bow

Sideload APK: `dist/AmbushLoop-v0.5.23-touch-slide.apk`  
Release tag: `v0.5.23-touch-slide`

Same RAID as 0.5.22 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷再收**: silhouettes shrink (~0.34), observation rings ~0.28. Dest cells / span 2 / first-follower pocket / yellow-cone fade / west wall clearance unchanged from 0.5.22.
- **绕箱南走廊**: far-side bow cap tightens to ~24px (was ~28px) so the string sits closer to the y=13 gap. Still walkable, axis_run 0, east overshoot 0.
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + first-follower pocket, compact narrow pack, crate-face axis_run 0, and south-corridor far-side cap.

### Android
- `versionName` 0.5.23 / `versionCode` 29 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.23 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: bodies look smaller than 0.5.22; first follower still stands a cell further along the file. Yellow cone still faded.

## 0.5.22 — Phone feel: first follower out of pocket, south-corridor east-exit

Sideload APK: `dist/AmbushLoop-v0.5.22-touch-slide.apk`  
Release tag: `v0.5.22-touch-slide`

Same RAID as 0.5.21 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷落点**: first follower leaves the 1-cell pocket along-file (still dx=1, not hugging the west wall). Second stays staggered further back. Dest span ≤2. Gameplay cone / ambush / RAID rules unchanged.
- **绕箱南走廊**: polar samples that punched through the far crate no longer wrap east around the south block. The string stays in the y=13 gap, still bowed off-axis and walkable.
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + first-follower pocket, compact narrow pack, crate-face axis_run 0, and south-corridor east-exit.

### Android
- `versionName` 0.5.22 / `versionCode` 28 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.22 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: first follower stands a cell further along the file, not on the lead's diagonal. Yellow cone still faded.

## 0.5.21 — Phone feel: west dest span 2, remaining crate-face bow

Sideload APK: `dist/AmbushLoop-v0.5.21-touch-slide.apk`  
Release tag: `v0.5.21-touch-slide`

Same RAID as 0.5.20 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷落点**: dest-cell contract now span ≤2. First follower stays 1-cell diagonal; second stands one cell further back so the trio is not three bodies in a 1-cell pocket under the yellow cone. Gameplay cone / ambush / RAID rules unchanged.
- **复杂箱群弧**: leftover 1-segment wall-aligned samples on the south face bow off-axis. Samples stay walkable.
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone + dest span 2, compact narrow pack, and crate-face axis_run 0.

### Android
- `versionName` 0.5.21 / `versionCode` 27 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.21 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: first follower hugs the 1-cell diagonal; the second stands a cell further back. Yellow cone still faded.

## 0.5.20 — Phone feel: west cone fade, smaller trio, bowed crate-wall arc

Sideload APK: `dist/AmbushLoop-v0.5.20-touch-slide.apk`  
Release tag: `v0.5.20-touch-slide`

Same RAID as 0.5.19 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷再收**: silhouettes shrink (~0.40), observation rings ~0.36, camera pullback ~0.44. Yellow cone *fill* fades (~0.38) in the west trio — gameplay cone / dest cells unchanged (span ≤1).
- **复杂箱群弧**: wall-aligned snag runs bow off the crate face (axis-run 2 → 1 target). Samples stay walkable.
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio + faded cone, compact narrow pack, and bowed multi-crate arc.

### Android
- `versionName` 0.5.20 / `versionCode` 26 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.20 COMMANDOS/WW2**.
2. Compact bar still stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: bodies look smaller, yellow cone is fainter, they stand farther apart around the crate.

## 0.5.19 — Phone feel: west clearer, compact 5-key narrow pack, rounder crate-cluster arc

Sideload APK: `dist/AmbushLoop-v0.5.19-touch-slide.apk`  
Release tag: `v0.5.19-touch-slide`

Same RAID as 0.5.18 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷再收**: silhouettes shrink (~0.46), observation rings ~0.44, camera pullback ~0.48. Dest worlds sit farther on the side with more along-file stagger. Dest cells still span ≤1.
- **简配 5 键窄屏**: 匍匐/背包 stack into a 2-row column; ↺/↻ sit with 需枪 in the right thumb cluster. Smaller type. Hold or swipe either twist key still works on a ~320px remaining strip.
- **复杂箱群弧**: snag scores same-radius around vs outward so the south face of a crate block stays bowed, not a wall-slide. Samples stay walkable.
- Forced-touch path covers settle-on-ring, bidirectional ↺/↻, west trio, compact narrow pack, and rounder multi-crate arc.

### Android
- `versionName` 0.5.19 / `versionCode` 25 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.19 COMMANDOS/WW2**.
2. Compact bar stacks **匍匐** over **背包**; **↺ / ↻** sit next to **需枪**. Hold or swipe either way.
3. West alley **跟**: bodies look smaller, camera pulls further, they stand farther apart around the crate.

## 0.5.18 — Phone feel: settle on ring after ↻, compact ↺/swipe, west tighter, rounder crate-cluster arc

Sideload APK: `dist/AmbushLoop-v0.5.18-touch-slide.apk`  
Release tag: `v0.5.18-touch-slide`

Same RAID as 0.5.17 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **停住留环**: after releasing ↻ / finishing a twist, follower *bodies* stay on the ring half-cell. Dest cells stay discrete (span≤1); bodies no longer snap back to dest-cell centers.
- **简配 ↺ + 左右滑**: compact SETUP shows 匍匐 / 背包 / ↺ / ↻ / 需枪. Hold either twist button, or swipe left/right across them, both directions, continuous.
- **西巷再收**: silhouettes shrink (~0.54) and dest worlds sit farther on the side; along-file stagger so the three bodies stick less. Dest cells still span ≤1.
- **复杂箱群弧**: crate-cluster clamps search outward / by angle first (inward wall-slide last) and restore bow, so samples stay rounder and still walkable.
- Forced-touch path covers settle-on-ring, compact ↺/swipe, west tighter, and rounder multi-crate arc.

### Android
- `versionName` 0.5.18 / `versionCode` 24 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.18 COMMANDOS/WW2**.
2. Compact bar shows **↺** and **↻**. Hold or swipe either way: followers slide around the lead and stay there when you let go.
3. West alley **跟**: bodies look smaller and stand farther apart around the crate.

## 0.5.17 — Phone feel: follower bodies ride the slot ring, west shrink/half-cell, compact ↻, rounder crate arc

Sideload APK: `dist/AmbushLoop-v0.5.17-touch-slide.apk`  
Release tag: `v0.5.17-touch-slide`

Same RAID as 0.5.16 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **跟班身体沿环**: while tapping or holding ↻, follower *bodies* polar-slide on the facing-slot ring. Dest cells stay discrete (span≤1); the bodies no longer grid-walk the hop.
- **西巷三人**: silhouettes shrink (~0.66) and dest worlds sit a half-cell further on the side so the three bodies overlap less. Dest cells still span ≤1.
- **简配底栏 ↻**: compact night-raid SETUP shows 匍匐 / 背包 / ↻ / 需枪. Hold ↻ repeats so the file keeps sliding on the ring (not only the full desktop rail).
- **绕箱圆弧**: crate clamps search radially / by angle first, so the path stays bowed instead of sliding flat along the crate face.
- Forced-touch path covers body ring, west scale/half-cell, compact ↻ hold, and rounder walkable arc.

### Android
- `versionName` 0.5.17 / `versionCode` 23 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.17 COMMANDOS/WW2**.
2. Compact bar shows **↻** next to 背包. Hold it: followers slide around the lead.
3. West alley **跟**: bodies look smaller and stand off cell centers around the crate.

## 0.5.16 — Phone feel: 15° ↻ dests ride the slot ring, west stagger/scale, walkable arc

Sideload APK: `dist/AmbushLoop-v0.5.16-touch-slide.apk`  
Release tag: `v0.5.16-touch-slide`

Same RAID as 0.5.15 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **按住/连拧 ↻**: dest markers polar-slide around the facing-slot ring on every 15° tap (and while holding ↻ / A·D). They no longer wait for a ~90° twist or hop cell-by-cell.
- **西巷三人**: dest worlds push another half cell apart along the side, and operator silhouettes shrink (~0.80) while the west file is clustered, so the three bodies overlap less.
- **圆弧穿箱**: arc samples snag onto walkable cells. The slot-ring feel stays, dests do not clip through crates.
- Forced-touch path covers 15° ring, west stagger/scale, and walkable arc clamp.

### Android
- `versionName` 0.5.16 / `versionCode` 22 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.16 COMMANDOS/WW2**.
2. Stand still and tap ↻ once (15°): dests slide around the lead, they do not hop a whole tile.
3. West alley **跟**: dests sit farther apart around the crate, bodies look a bit smaller.

## 0.5.15 — Phone feel: west trio rings tighten, 90° dests slide on the slot arc

Sideload APK: `dist/AmbushLoop-v0.5.15-touch-slide.apk`  
Release tag: `v0.5.15-touch-slide`

Same RAID as 0.5.14 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷三人观察环** shrinks (~0.52 of kit range) while the west file is clustered, so the cyan ring overlaps the yellow cone less.
- Camera pulls farther (~0.54) and still **holds** that pullback on the trio + cone. West dests sit on the back/side corner of the cell (~15px inset) instead of the cell center.
- **90° 大拧射界**: dest world and followers interpolate along the facing-slot arc around the lead (~0.30s), not a 3-cell grid walk. Small 15–20° hops still use the short cell lerp.
- Forced-touch path covers west ring/camera tighten and the 90° arc slide.

### Android
- `versionName` 0.5.15 / `versionCode` 21 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.15 COMMANDOS/WW2**.
2. West alley **跟**: observation ring is smaller, camera stays pulled back past 0.62, dests sit toward cell corners around the crate.
3. Stand still and twist 射界 ~90°: followers slide around the lead, they do not walk three tiles.

## 0.5.14 — Phone feel: west 1-cell diagonal + camera holds pullback, dests lerp toward slot

Sideload APK: `dist/AmbushLoop-v0.5.14-touch-slide.apk`  
Release tag: `v0.5.14-touch-slide`

Same RAID as 0.5.13 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷跟上** dests sit on a 1-cell diagonal behind the lead (around the west crate), not two cells due west against the wall. Yellow cone + three bodies overlap less.
- Camera pulls farther (~0.62) and **holds** that pullback while the west trio is clustered, including after they stop, and frames a bit of the cone.
- **拧射界换格**: dest world lerps toward the interpolated slot point inside the new cell (~0.24s hop, then a snappy ease). Followers slide to that point instead of teleporting to the cell center.
- Forced-touch path covers dest-hop interpolation, 拧射界换格, and 西巷三人跟上.

### Android
- `versionName` 0.5.14 / `versionCode` 20 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.14 COMMANDOS/WW2**.
2. West alley **跟**: dests sit north and south of the west crate, one cell behind the lead. Camera stays pulled back while they stand there.
3. Stand still and tap ↻ once: dests slide toward the new slot, they do not hop a whole tile to the cell center.

## 0.5.13 — Phone feel: west-alley 1-cell stagger + camera pullback, dest hops slide

Sideload APK: `dist/AmbushLoop-v0.5.13-touch-slide.apk`  
Release tag: `v0.5.13-touch-slide`

Same RAID as 0.5.12 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷跟上** packs one cell tighter: dests sit diagonal-rear of the lead (depth 1, left/right stagger). They no longer occupy two extra cells behind the yellow cone and block the sneak.
- Camera eases out (~0.78) while the west file walks so the cone + three bodies fit on screen, then eases back when they stop.
- **拧射界换格**: dest world slides ~0.2s between cells. A 15–20° twist still changes the dest cell, but followers no longer hitch on a whole-cell jump.
- Forced-touch path covers dest-hop interpolation, west rear/spacing, 拧射界换格, and 西巷三人跟上.

### Android
- `versionName` 0.5.13 / `versionCode` 19 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.13 COMMANDOS/WW2**.
2. West alley **跟**: dests sit one cell behind-side of the lead, not two cells due west. Camera pulls back while they walk.
3. Stand still and tap ↻ once: followers slide to the new dest, they do not hop a whole tile.

## 0.5.12 — Phone feel: 射界 dests interpolate with facing, 跟 chip off gun

Sideload APK: `dist/AmbushLoop-v0.5.12-touch-aim.apk`  
Release tag: `v0.5.12-touch-aim`

Same RAID as 0.5.11 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- Lead **拧射界** (A/D / ↺↻, 15° a tap): follow dests interpolate with the cone. A 20° twist already moves the file — dests no longer wait for the ~45° cardinal snap.
- West-alley rear file stays 2-cell behind with 1-cell left/right stagger. Camera eases toward the file while they walk. Dest cells prefer the interpolated slot over a wall hug.
- **跟** chip is a 36×18 top-right tab, raised off the gun stamp (6px gap). Gun / number / glyph still pick.
- Forced-touch path covers 20° 射界 nudge, 90° file turn, west rear file, badge partitions, and 西匣开匣 → 绕背 → 三人跟上.

### Android
- `versionName` 0.5.12 / `versionCode` 18 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.12 COMMANDOS/WW2**.
2. Stand still and tap ↻ once (15°): followers step. They do not wait until the cone faces south.
3. Portrait **跟** sits on the top-right corner; gun/number taps still select.

## 0.5.11 — Phone feel: west-alley rear file, 射界 twist turns the file, 跟 chip up

Sideload APK: `dist/AmbushLoop-v0.5.11-touch-form.apk`  
Release tag: `v0.5.11-touch-form`

Same RAID as 0.5.10 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **西巷跟上** dests sit behind the lead with a 1-cell left/right stagger. They no longer stretch into a north-south alley queue on the lead's column.
- Lead **only twists 射界** (A/D / ↺↻): the follow file turns with the cone. Walking still files behind the march; a stop without a twist still freezes the land cell.
- **跟** chip sits slightly proud of the portrait top-right (34×18). Gun stamp and number stay pick; they do not toggle 跟.
- Forced-touch path covers west rear file, 射界 twist, badge hit partitions, and 西匣开匣 → 绕背 → 三人跟上.

### Android
- `versionName` 0.5.11 / `versionCode` 17 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.11 COMMANDOS/WW2**.
2. In the west alley, tap **跟** on both: dests sit west of an east-facing lead, staggered, not stacked down the alley.
3. Stand still and twist 射界 90°: followers walk to the new rear. Portrait **跟** sits on the top-right corner; gun/number taps still select.

## 0.5.10 — Phone feel: follow files behind the lead, stop land freezes, 跟 probes

Sideload APK: `dist/AmbushLoop-v0.5.10-touch-rear.apk`  
Release tag: `v0.5.10-touch-rear`

Same RAID as 0.5.9 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **跟上** dests sit behind the lead. Two followers stagger left/right but stay rear; they no longer park on the hip or in front after a side-offset walk.
- After the lead **stops**, that rear dest freezes for another settle round. Arriving on the land cell does not take a second drop.
- **三人跟上 + 侧面绕背**: wrap dashed line still ≥4 cells around the sentry body; once the lead is on the back cell, followers file behind.
- **跟** chip is the 30×16 top-right hit. Glyph / name / HP / gun / stance / below-chip / inner-left taps select, they do not toggle 跟.
- Forced-touch path covers rear file, stop freeze, three-follow + side wrap, and badge probes.

### Android
- `versionName` 0.5.10 / `versionCode` 16 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.10 COMMANDOS/WW2**.
2. Tap **跟** and walk the lead east, then stop: followers stand behind, staggered, they do not line up on the hip.
3. After they land, they stay on that cell. 绕背 dashed line still wraps the sentry body.

## 0.5.9 — Phone feel: side 绕背 wraps sentry body, lead-stop formation holds, 跟 probes

Sideload APK: `dist/AmbushLoop-v0.5.9-touch-wrap.apk`  
Release tag: `v0.5.9-touch-wrap`

Same RAID as 0.5.8 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **贴身/侧面绕背** walks around the sentry 3×3 body to the back cell. Dashed guide is ≥4 grid cells, not a 2-cell hip stub.
- **跟上** keeps the walking dest after the lead stops. Formation does not drop one more cell off the 射界.
- **跟** chip is a 32×18 top-right hit. Glyph / name / HP / stance / below-chip taps select, they do not toggle 跟.
- Forced-touch path covers side wrap + three-person 跟上, lead-stop settle, and badge probes.

### Android
- `versionName` 0.5.9 / `versionCode` 15 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.9 COMMANDOS/WW2**.
2. Stand on a sentry's hip and tap **绕背**: dashed line arcs around the body to the back, it is not two dots.
3. Walk the lead with **跟** on, then stop: followers finish the same dest, they do not take one extra step.

## 0.5.8 — Phone feel: walk-follow continuity, full 绕背 dashed path, 跟 badge hit

Sideload APK: `dist/AmbushLoop-v0.5.8-touch-follow.apk`  
Release tag: `v0.5.8-touch-follow`

Same RAID as 0.5.7 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **跟上** while the lead is walking keeps one arrival slot. Dest no longer hops every tile; followers do not stop-start at the moving 射界 rim.
- **绕背** dashed guide is the full grid path to the backstab cell (4-connected, last cell is dest, no cone cut).
- **跟** chip is a smaller top-right hit. Tapping the portrait body selects; tapping the chip toggles follow. They do not overlap.
- Forced-touch path covers lead-walk follow + complete 绕背 guide, then 西匣开匣 → 绕背 → 三人跟上.

### Android
- `versionName` 0.5.8 / `versionCode` 14 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.8 COMMANDOS/WW2**.
2. Tap **跟** then walk the lead: followers keep walking, they do not stutter every cell.
3. 绕背 dashed line reaches the back cell. Portrait name/HP tap selects; only the corner chip toggles 跟.

## 0.5.7 — Phone feel: short 2–3 cell detour, west-alley spacing, 开匣→绕背→跟上

Sideload APK: `dist/AmbushLoop-v0.5.7-touch-detour.apk`  
Release tag: `v0.5.7-touch-detour`

Same RAID as 0.5.6 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **跟上** no longer idle-waits at the west alley when the lead is east of a cone. A 2–3 cell local sidestep around the cone / a teammate is allowed; courtyard wraps are still rejected.
- West-court three-person **跟上** keeps a one-cell gap (chebyshev ≥ 2, ~3 tiles in the alley) instead of stacking on the lead's heels.
- Forced-touch path is still one story: west **开匣** → **绕背** → three-person **跟上**, now covering the wait and crowd cases.
- Crowded west-alley taps still do not body-select a stacked teammate or fire **开匣**.

### Android
- `versionName` 0.5.7 / `versionCode` 13 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.7 COMMANDOS/WW2**.
2. Lead east of a yellow cone, followers in the west alley: they walk a short detour, they do not freeze.
3. West alley, three **跟上**: dests stay a cell apart, they do not pile on the same tile.

## 0.5.6 — Phone feel: follow dest rim, west-alley queue, 开匣→绕背→跟上

Sideload APK: `dist/AmbushLoop-v0.5.6-touch-queue.apk`  
Release tag: `v0.5.6-touch-queue`

Same RAID as 0.5.5 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **跟上** destinations sit farther off the yellow cone (painted sector + ~2 cell rim). They no longer hug the cone outline.
- West-court three-person **跟上** queues / staggers in the alley instead of wrapping the courtyard. Destinations stay west of the cone; one waits if the next cell is occupied.
- Forced-touch path is one story: west **开匣** → **绕背** → three-person **跟上**.
- Phone taps no longer body-select a stacked teammate (portraits pick people). Cover pads only eat the pad cell.

### Android
- `versionName` 0.5.6 / `versionCode` 12 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.6 COMMANDOS/WW2**.
2. 跟上 toward a yellow cone: dashed dest sits off the rim, not on the outline.
3. West alley, three **跟上**: they line up in the corridor, they do not loop the yard.

## 0.5.5 — Phone feel: follow stays outside 射界, 射界 ink hidden

Sideload APK: `dist/AmbushLoop-v0.5.5-touch-outside.apk`  
Release tag: `v0.5.5-touch-outside`

Same RAID as 0.5.4 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- **跟上** into an existing yellow cone stops outside or walks around. Already inside: walk out, then hold the rim. Destinations skip the selected operator's 射界, sentry cones, crates, and cover pads.
- Compass / 「射界」 world ink under the feet hides on phone so it does not eat taps. Desktop still shows the rose.
- Forced-touch path: west-court **开匣** → **绕背** (path clears the cone and the west crates) → three-person **跟上**.
- Followers no longer stack on a crate/pad; 绕背 dest is never the cell you already stand on.

### Android
- `versionName` 0.5.5 / `versionCode` 11 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.5 COMMANDOS/WW2**.
2. Select someone: no 「射界」 caption under their boots.
3. 跟上 toward a yellow cone: dashed path wraps or stops on the rim, does not cut the yellow.

## 0.5.4 — Phone feel: crate names off, 绕背 clears west court, follow spacing

Sideload APK: `dist/AmbushLoop-v0.5.4-touch-clear.apk`  
Release tag: `v0.5.4-touch-clear`

Same RAID as 0.5.3 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- Crate gun names (Kar98k / MG42 / …) hide on phone. Gun stamp stays; 开匣 % only while standing on the box.
- **绕背** is a smaller chip pinned to the operator, not the dest cell. It only appears in the rear, and it is nudged off west-court crates and pads.
- **跟上** fans back-left / back-right (~2 cells) and reserves cells so two followers do not stack on the lead.
- Hotspots: crate/cover must be the same cell; 绕背 range tightened; courtyard loop taps still walk.

### Android
- `versionName` 0.5.4 / `versionCode` 10 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.4 COMMANDOS/WW2**.
2. Force-touch: courtyard crates have no Kar98k/M1911 captions. Bottom bar still 匍匐 / 背包 / 需枪.
3. Stand west of an east-facing sentry: **绕背** sits beside you, not on the west rifle crate.

## 0.5.3 — Phone feel: north ink, cone-avoid 绕背/跟上, tighter hotspots, yard loop

Sideload APK: `dist/AmbushLoop-v0.5.3-touch-smooth.apk`  
Release tag: `v0.5.3-touch-smooth`

Same RAID as 0.5.2 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- North-edge world text hides: spawn captions, 主路/侧翼 route tags, cover names, 伏击区/第二层, 岗哨/观察环/干员名牌. Diamonds and dashed paths stay. Labels never eat taps.
- 绕背 and **跟上** path around the yellow cone (plus a body halo). They no longer walk the cone rim and brush the sentry.
- Crate/cover/口哨 hotspots only while standing still, and only on the object (not the next cell). Walking a courtyard loop no longer pops 开匣.
- Force-touch dump walks the yard by simulated taps; smoke asserts the loop.

### Android
- `versionName` 0.5.3 / `versionCode` 9 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.3 COMMANDOS/WW2**.
2. Force-touch: north wall of the yard has no 敌1/主路·巡/北廊掩体 captions. Bottom bar still 匍匐 / 背包 / 需枪.
3. Stand west of a south-facing sentry and 绕背: dashed path wraps the cone, does not cut the yellow.

## 0.5.2 — Phone feel: north fold, 绕背, gesture split, follow

Sideload APK: `dist/AmbushLoop-v0.5.2-touch-feel.apk`  
Release tag: `v0.5.2-touch-feel`

Same RAID as 0.5.1 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). Phone default stays 简配夜袭.

### Play (phone)
- North chrome folds into the title band: route chips, spawn teach, and the SCOUT timeline no longer sit on the courtyard wall.
- Near a sentry's back: **绕背** hotspot + dashed guide (auto-knives on arrival). Already behind: **割喉**. Front: **口哨**.
- Short drag pans the map; long-press on empty ground sprints. Finger jitter under 22px does not steal the hold.
- Cover pads only eat a tap on the pad itself; walking a courtyard loop no longer teleports onto every nearby sandbag.
- Unselected portraits show **跟** / **跟上**. Followers path behind the selected operator and stop at a yellow cone.

### Android
- `versionName` 0.5.2 / `versionCode` 8 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.2 COMMANDOS/WW2**.
2. Force-touch: north wall of the yard is free of 主路/侧翼 chips and the timeline. Bottom bar still 匍匐 / 背包 / 需枪.
3. Stand west of a sentry facing east, ~2 cells back: hotspot reads **绕背**, not 口哨.

## 0.5.1 — Phone simplified night-raid rail

Sideload APK: `dist/AmbushLoop-v0.5.1-touch-rail.apk`  
Release tag: `v0.5.1-touch-rail`

Same RAID as 0.5.0 (`SCOUT → ALERT → SWEEP`, auto fire + auto nade). The 16-key SETUP translator is gone on touch.

### Play (phone default)
- SETUP resident keys: **匍匐 · 背包 · 需枪**. Portraits sit in the left thumb band, not the courtyard.
- World verbs are **context hotspots** (开匣 / 割喉 behind / 口哨 front / 搜尸+拖尸 / 上掩体 / 捆绑 / 包扎).
- ALERT bar is **暂停 / 倍速 / 中止** (abort asks once). Auto-nade toggle lives in the pause menu.
- Left operator cards, skill bar, and minimap hide on phone. Long-press a portrait for the overflow skill wheel.
- Desktop keyboard chrome is unchanged. Settings → 触控底栏 uses the phone rail, not 16 keys.

### Android
- `versionName` 0.5.1 / `versionCode` 7 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.1 COMMANDOS/WW2**.
2. Force-touch / phone: bottom bar is three portraits + 匍匐 + 背包 + 需枪. No 14-key row.
3. Pull alarm: only 暂停 / 1× / 中止. Portraits stay on the thumb plate.

## 0.5.0 — Commandos 2 portraits, skills, sentry cones

Sideload APK: `dist/AmbushLoop-v0.5.0-commandos2-kit.apk`  
Release tag: `v0.5.0-commandos2-kit`

100 perceivable iterations on the v0.4.0 kit. RAID is still SCOUT → ALERT → SWEEP. Alarm still freezes walking.

### Play
- Bottom **portraits**, skill hotbar (C/Q/W/Z, 4–8), minimap, context cursor, dest X.
- SCOUT **岗哨** with yellow LOS cones. Crouch in bushes to hide. Q backstab. Whistle peels. Does **not** auto-pull the alarm.
- Double-click sprint, Shift walk, wheel zoom, F1 follow / F2 recage, middle-pan.
- Quiet yard (all sentries down) → extra nade + win star.
- ALERT: enemy red cones; auto fire + auto nade unchanged.

### Android
- `versionName` 0.5.0 / `versionCode` 6 (`com.ambushloop.game`).

### How to tell you have this build
1. Title **v0.5.0 COMMANDOS/WW2** · **点选单兵 · 搜刮潜行**.
2. Bottom three portraits. Yard spine has a walking 岗哨 with a yellow cone.
3. Pull alarm: **警报中 · 第N/M波**, walking still frozen.

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
