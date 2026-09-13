# Human playtest notes (raid loop)

Play on `cursor/commandos-ambush-0641`. Yard first.

## How it should feel
1. Three ops spawn with knives. Walk to crates. **Stand still 0.4s** to open.
2. Rifle ammo does not load into an MG. **I** opens the 6-slot pack. Pass gear with **T**.
3. Alarm button says 需枪 until someone loots a firearm. Second press force-pulls.
4. Wave 1, sweep corpses (H to drag off the road), wave 2, extract.
5. Touch: 雷点 / 背包 / 诱饵 / 递装. Alert: auto fire + auto nades (toggle 自动雷).

## Known gaps
- No multi-floor / climb / vehicles (contract cut).
- Alarm still freezes walking (auto fire + auto nade).
- Body drag is presentation + slow; enemies do not "spot" corpses.
- Hold-to-move is an opt-in GameSettings flag (`hold_to_move`).

## Failures to try
- Knives-only alarm (second press): yard flank leaks. Fail card should say **第N波漏网**.
- Dry MG: pistol pool should swap in if you looted pistol ammo earlier.
- Friendly grenade: damages nearby ops, voids the 无人受伤 star.
