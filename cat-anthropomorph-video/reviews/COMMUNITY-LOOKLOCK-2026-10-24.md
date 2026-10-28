# Community Looklock Plan · Qwen-Image-Edit-2511 (2026-10-24)

> Scope: `cat-anthropomorph-video/` SFW looklock only. No merge. No NSFW. Do not touch `ai-realistic-comic/`.
> Goal: repo tip ready for a real GPU looklock run on AutoDL 4090.

## Precision policy (do not confuse with Wan)

| Stack | Default precision | Notes |
| --- | --- | --- |
| Wan2.1 I2V / FLF2V | **fp16** | fp8_e4m3fn is VRAM fallback only; noisy. |
| Qwen-Image-Edit-2511 looklock | **`qwen_image_edit_2511_fp8mixed`** | Wan “ban fp8” does **not** apply to Qwen. |

### Global launch rules
- Never document or enable `--use-sage-attention`.
- Do **not** add `--force-fp16` for Qwen (black-image risk).
- Lightning / Turbo 4-step LoRA: optional speed only; **default OFF** for quality gate.
- Lightning LoRA only with **fp8mixed** base — never stack on a fused lightning checkpoint.

## Weights (manifest group `looklock`)
- Required: `qwen_image_edit_2511_fp8mixed.safetensors` + `qwen_2.5_vl_7b_fp8_scaled.safetensors` + `qwen_image_vae.safetensors`
- Optional: Lightning 4steps LoRA; bf16 full UNET only if VRAM/disk allow
- Optional costume ref: `$INPUT_ROOT/looklock/costume_ref_PLACEHOLDER.png` (clothing/pose reference; not a weight)

## Workflow `01_looklock_qwen_edit.json`
- Align with official Comfy template `image_qwen_image_edit_2511` topology.
- LoadImage defaults: `cats/A/raw/front.jpg` + costume placeholder.
- Positive: orange-white longhair cat → upright anthropomorphic US Normandy / WWII US infantry (ears visible, SFW, no weapons).
- Turbo/Lightning default OFF.
- MarkdownNote must warn: Wan-fp16 ≠ Qwen-fp8mixed.

## Scripts
- `restore.sh --group looklock` dry-run prints the precision policy above.
- Copies `refs/cats/*/front.jpg` (and `cat-*.jpg`) into `$INPUT_ROOT/cats/*/raw/`.
- Fail closed: no silent fallback looklock → I2V.

## Boot note
Download fp8mixed + TE + VAE; no sage; no force-fp16 on Qwen; then open `workflow/01_looklock_qwen_edit.json`.

## PR checklist
1. manifest looklock notes (fp8mixed OK; Lightning only on fp8mixed; costume_ref path)
2. workflow 01 hardened (paths, prompt, Lightning OFF, MarkdownNote)
3. restore/smoke precision policy + ref copy + fail-closed
4. README-PIPELINE / NEXT-BOOT looklock boot note
5. this brief under `reviews/COMMUNITY-LOOKLOCK-2026-10-24.md`
