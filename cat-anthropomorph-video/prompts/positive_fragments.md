# 正向提示片段（可拼接）

## 钢盔 / 帽 · 露耳（必用思路）

- 美军（A）：`US WWII infantry helmet with ear cutouts, cat ears clearly visible through helmet openings, soft fur on ears, forehead markings visible`
- 苏军（B）：`Soviet WWII side cap or ushanka with red star, cat ears emerging from cap openings, whiskers visible`
- 飞行员（C）：`leather flight helmet with ear openings for cat ears, goggles on forehead or over eyes, white scarf, no aircraft insignia in frame`

## 少持枪约束（正向改写）

优先写：

- `holding a flag / binoculars / map case / canteen`
- `running, looking up at the sky, climbing rubble, saluting, shaking hands`
- `empty-handed dramatic pose, cape or scarf motion`

避免默认 `holding a rifle`；若叙事必须出现枪械：远景、背影、枪口不对准镜头，且每条慎用。

## 画风锚点

`photoreal cinematic still, anthropomorphic cat person (cat head, human body), vintage newsreel color grade, vertical 9:16 framing, SFW`

## 通用动作句（I2V / FLF2V 可改）

- `dust and smoke in backlight, fabric and fur reacting to wind`
- `decisive action hit on the beat, then brief hold`
- 详见下方 **I2V 动作模板**（R1 敬礼 / R4 抬头）；勿用 soft 词


## I2V 动作模板（2026-10-25 · 强动词，禁 soft 词）

> 规则：动作放句首；用 raise / snap / hold / whip / stare；**禁止** gentle / slightly / small / soft / subtle。
> Fixed camera；短锚 same face / fur / uniform。一条片段只做一个主动作。

### R1 / R2 · 敬礼（workflow `02` 默认正向）

```txt
The anthropomorphic cat soldier quickly raises her right paw to the brim of her helmet in a crisp military salute and holds the salute firmly; her chin lifts and she stares straight into the camera; her red neckerchief flutters strongly in the wind. Fixed camera, medium shot, same face, fur pattern and US Army uniform as the first frame.
```

### R4 · 抬头 + 围巾（手被竖裁切掉时的低风险备胎）

```txt
The anthropomorphic cat soldier snaps her head up and turns to stare directly into the camera, ears perking forward; strong wind whips her red neckerchief and blows dust across the frame. Fixed camera, medium close-up, same face, fur pattern and US Army uniform as the first frame.
```

### R3 采样回退（非默认）

仅当 R1、R2 未过 `motion_gate`（G2m）时：保持 length=49 与 R1 正向，改 **cfg=5 / shift=10**（steps 仍 20）。

### 身份回退（非默认，社区记录）

仅当身份明显漂移且动作已过线：可试官方 480p 口径 **shift=3 / steps=40**（length 仍 49）；这会牺牲部分动作，**不改默认**。Lightning 默认 OFF，勿用 CFG=1 省步。


## B0-01 三战役高光镜（v0.1g · 门落 / 爆破开路 / 插旗剪影）

> 方案 A 锁定参数不变。首帧 = **scene_lock_first_frame**（诺曼底符号已在静帧里）。验收：一眼可读对应符号。参数键见 `workflow/02_i2v_api_prompt_r1_r4.json`。

### H1 · 门落（ramp door drop）

```txt
The landing craft bow ramp suddenly drops open with a heavy slam; bright gray Normandy daylight floods the troop compartment; the upright bipedal anthropomorphic orange-and-white cat soldier in US olive-drab field kit braces and steps forward toward the open ramp. Fixed camera inside the Higgins boat looking out, medium-wide, same face, fur pattern and US Army uniform as the first frame; readable Normandy LCVP / ramp door symbol in frame.
```

验收：登陆艇门/坡道 + 直立美军拟人猫。

### H2 · 爆破开路（blast breach）

```txt
A sharp beach obstacle blast erupts ahead in dust and smoke; the upright bipedal anthropomorphic orange-and-white cat soldier in US WWII field jacket ducks then surges forward through the clearing path on Omaha-like sand. Fixed camera, medium shot, same face, fur pattern and uniform as the first frame; clear Normandy beach / hedgehog / smoke symbol.
```

验收：滩头障碍/烟尘爆破 + 前进开路。

### H3 · 插旗剪影（flag silhouette）

```txt
The upright bipedal anthropomorphic orange-and-white cat soldier plants a small US flag into the Normandy sand and holds the pose as a backlight silhouette; wind snaps the flag and her red neckerchief. Fixed camera, hero wide-to-medium, same face and fur as the first frame; unmistakable flag-planting Normandy silhouette.
```

验收：插旗剪影 / 诺曼底滩头符号。

