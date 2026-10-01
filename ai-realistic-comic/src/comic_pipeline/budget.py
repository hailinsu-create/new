from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

# Approximate fal list prices (USD / megapixel), portrait rounds up to ~1 MP.
COST_T2I_USD = 0.025
COST_PULID_USD = 0.0333
COST_SEEDREAM_USD = 0.03
COST_QA_USD = 0.005
COST_STRICT_USD = 0.03  # reasoning VLM second opinion, conservative guess
COST_GPT_IMAGE_USD = 0.06  # gpt-image-1.5 edit, medium quality, 1024x1536 (conservative)
COST_NANO_BANANA_PRO_USD = 0.15  # fal list price per 1K/2K image
COST_UPSCALE_USD = 0.02  # conservative guess; fal bills aura-sr by output size


@dataclass
class BudgetLedger:
    limit_usd: float
    spent_usd: float = 0.0
    events: list[dict] = field(default_factory=list)

    @classmethod
    def load_or_new(cls, path: Path, limit_usd: float) -> "BudgetLedger":
        if path.is_file():
            data = json.loads(path.read_text(encoding="utf-8"))
            return cls(
                limit_usd=limit_usd,
                spent_usd=float(data.get("spent_usd", 0.0)),
                events=list(data.get("events", [])),
            )
        return cls(limit_usd=limit_usd)

    def estimate(self, model: str) -> float:
        if "aura-sr" in model.lower() or "upscale" in model.lower():
            return COST_UPSCALE_USD
        if "nano-banana-pro" in model.lower():
            return COST_NANO_BANANA_PRO_USD
        if "gpt-image" in model.lower():
            return COST_GPT_IMAGE_USD
        if "gemini-2.5-pro" in model.lower():
            return COST_STRICT_USD
        if "any-llm" in model.lower():
            return COST_QA_USD
        if "seedream" in model.lower():
            return COST_SEEDREAM_USD
        if "pulid" in model.lower():
            return COST_PULID_USD
        return COST_T2I_USD

    def remaining(self) -> float:
        return max(0.0, self.limit_usd - self.spent_usd)

    def ensure_can_afford(self, model: str) -> None:
        need = self.estimate(model)
        if self.spent_usd + need > self.limit_usd + 1e-9:
            raise RuntimeError(
                f"Budget exceeded: need ${need:.4f} for {model}, "
                f"spent ${self.spent_usd:.4f} / limit ${self.limit_usd:.4f}. "
                "Raise COMIC_BUDGET_USD or reuse cache (omit --force)."
            )

    def charge(self, *, model: str, panel_id: str, cached: bool = False) -> float:
        if cached:
            self.events.append(
                {"panel_id": panel_id, "model": model, "usd": 0.0, "cached": True}
            )
            return 0.0
        amount = self.estimate(model)
        self.ensure_can_afford(model)
        self.spent_usd += amount
        self.events.append(
            {
                "panel_id": panel_id,
                "model": model,
                "usd": amount,
                "cached": False,
                "spent_total": round(self.spent_usd, 4),
            }
        )
        return amount

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "limit_usd": self.limit_usd,
                    "spent_usd": round(self.spent_usd, 4),
                    "remaining_usd": round(self.remaining(), 4),
                    "events": self.events,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
