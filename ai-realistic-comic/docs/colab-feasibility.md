# ABANDONED — Colab path

2026-10-01: Google AI Pro on the available account did not unlock Colab paid GPUs (A100/L4 unavailable; free T4 only). Workflow moved to **AutoDL rented GPUs** — see [autodl.md](autodl.md).

---

# Moving image generation to Google Colab (Google AI Pro) - feasibility, 2026-10-01

Sources: Colab FAQ https://research.google.com/colaboratory/faq.html, Google One help
https://support.google.com/googleone/answer/14534406, Colab blog
https://developers.googleblog.com/colab-is-now-part-of-your-google-ai-plan/, CLI https://github.com/googlecolab/google-colab-cli (+ issue #47).

## What is confirmed
- Google AI Pro includes 200 Colab compute units (CU) per month, web only, 18+, not during a free trial. Ultra adds background execution
  and "premium GPU" access; Pro gets "priority access to faster accelerators". Colab benefits roll out to supported countries.
- Rates (third-party figures): A100 40GB about 5.4 CU/h, A100 80GB about 7.5 CU/h, so 200 CU is roughly 26-37 A100 hours, never guaranteed.
  A user comment on the post this came from says a Pro account only showed three runtime types, so A100 availability on Pro is NOT confirmed.
- Colab CLI (`colab new --gpu A100`, `colab run`, `colab install`, `colab drivemount`) can be driven by an agent, but it does not expose remaining CU or
  CU/hour, so an agent cannot enforce a budget (issue #47).
- Colab forbids: creating deepfakes, connecting to remote proxies, file hosting/media serving, multiple accounts to dodge limits, bypassing anti-abuse.
  Runtimes also end at 12h (24h on Pro+), and the VM disk is wiped; persistence needs Drive.

## What it cannot replace
- The approved stills come from `fal-ai/nano-banana-pro/edit`, a closed model. It cannot run on Colab. Open models (Qwen-Image-Edit, FLUX-family, SDXL +
  IP-Adapter/PuLID) are what a Colab GPU can run, and earlier tests here showed them well below the approved quality for two-character consistency.
- Colab does not remove content rules: fictional adults only, no real-person likenesses, no circumventing platform filters.

## Where Colab is worth using
1. Hand/feet repair: local inpainting of hand regions on finished stills (free per image; addresses the extra-finger problem without re-rolling at $0.15).
2. Upscale/face-detail passes instead of aura-sr.
3. Character LoRA experiments on the look sheets to see whether an open model can match nano-banana-pro consistency before any migration.
4. Image-to-video of finished stills later.

## Constraints
- The agent cannot log in to your Google account. Colab CLI auth is interactive, so it must run on your own machine; do not put Google credentials in
  cloud secrets.
- Only run it where Colab/AI Pro is actually supported for your account.
