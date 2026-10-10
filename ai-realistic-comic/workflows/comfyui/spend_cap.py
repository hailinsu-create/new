"""Session spend hard-stop for AutoDL fox/centaur pilots.

AutoDL payg GPU bills settle about hourly, so wallet delta lag can hide a full
hour of GPU burn. Caps MUST therefore combine:

1. wallet delta (when settlements post), and
2. projected GPU burn from boot timestamp x payg rate.

Also: any monitor/SSH death must shutdown-fleet; never leave GPU on for judge.
Data-disk daily settle (~0.67 CNY/100GiB/day per machine) still drains wallet.
"""
from __future__ import annotations

import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_PAYG_LI_PER_HOUR = 2880
DEFAULT_DISK_RESERVE_YUAN = 1.40


@dataclass
class SpendCap:
    start_bal: float
    cap_yuan: float
    session_path: Path
    payg_li_per_hour: int = DEFAULT_PAYG_LI_PER_HOUR
    disk_reserve_yuan: float = DEFAULT_DISK_RESERVE_YUAN
    boot_mono: float | None = None
    boot_at: str | None = None

    def save(self) -> None:
        self.session_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "start_bal": self.start_bal,
            "cap_yuan": self.cap_yuan,
            "payg_li_per_hour": self.payg_li_per_hour,
            "disk_reserve_yuan": self.disk_reserve_yuan,
            "boot_at": self.boot_at,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        self.session_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "
",
            encoding="utf-8",
        )

    @classmethod
    def load(cls, path: Path) -> "SpendCap | None":
        if not path.is_file():
            return None
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls(
            start_bal=float(data["start_bal"]),
            cap_yuan=float(data["cap_yuan"]),
            session_path=path,
            payg_li_per_hour=int(data.get("payg_li_per_hour", DEFAULT_PAYG_LI_PER_HOUR)),
            disk_reserve_yuan=float(data.get("disk_reserve_yuan", DEFAULT_DISK_RESERVE_YUAN)),
            boot_at=data.get("boot_at"),
        )

    def mark_boot(self) -> None:
        self.boot_mono = time.monotonic()
        self.boot_at = datetime.now(timezone.utc).isoformat()
        self.save()

    def wallet_spent(self, bal_now: float) -> float:
        if self.start_bal < 0 or bal_now < 0:
            return 0.0
        return max(0.0, self.start_bal - bal_now)

    def projected_gpu_yuan(self) -> float:
        if self.boot_mono is None:
            return 0.0
        hours = max(0.0, (time.monotonic() - self.boot_mono) / 3600.0)
        return hours * (self.payg_li_per_hour / 1000.0)

    def effective_spent(self, bal_now: float) -> float:
        wallet = self.wallet_spent(bal_now)
        proj = self.projected_gpu_yuan()
        disk = self.disk_reserve_yuan if self.boot_mono is not None else 0.0
        return max(wallet, proj + disk)

    def remaining(self, bal_now: float) -> float:
        return self.cap_yuan - self.effective_spent(bal_now)

    def breached(self, bal_now: float) -> bool:
        return self.effective_spent(bal_now) >= self.cap_yuan

    def refuse_power_on(self, bal_now: float) -> str | None:
        spent = self.wallet_spent(bal_now)
        if spent >= self.cap_yuan:
            return (
                f"CAP_HARD_STOP refuse power_on: wallet spent {spent:.2f}>="
                f"{self.cap_yuan:.2f} (start {self.start_bal:.2f} now {bal_now:.2f})"
            )
        headroom = self.cap_yuan - spent
        min_need = self.disk_reserve_yuan + (self.payg_li_per_hour / 1000.0) * (10 / 60.0)
        if headroom < min_need:
            return (
                f"CAP_HARD_STOP refuse power_on: headroom {headroom:.2f} < "
                f"min_need {min_need:.2f} (disk_reserve+10min GPU)"
            )
        return None
