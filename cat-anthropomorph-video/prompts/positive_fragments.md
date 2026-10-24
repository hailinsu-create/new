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

