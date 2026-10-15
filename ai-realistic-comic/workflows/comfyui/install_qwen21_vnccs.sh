#!/usr/bin/env bash
# Run ON the AutoDL box (ComfyUI root = $COMFY). df before/after.
set -euo pipefail
COMFY="${COMFY:-/root/autodl-tmp/ComfyUI}"
echo "DF_BEFORE"; df -h "$COMFY" /root/autodl-tmp 2>/dev/null || df -h
mkdir -p "$COMFY/models/diffusion_models" "$COMFY/models/text_encoders" "$COMFY/models/vae" "$COMFY/models/loras" "$COMFY/custom_nodes"
# Base int8 trio via hf-mirror
wget -c -P "$COMFY/models/diffusion_models" \
  "https://hf-mirror.com/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_int8_convrot.safetensors"
wget -c -P "$COMFY/models/text_encoders" \
  "https://hf-mirror.com/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors"
wget -c -P "$COMFY/models/vae" \
  "https://hf-mirror.com/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors"
# VNCCS LoRA + edit LoRA (Civitai NSFW LoRAs need manual/token; try HF mirrors first)
wget -c -P "$COMFY/models/loras" \
  "https://hf-mirror.com/MIUProject/VNCCS_PoseStudio_QI2.1/resolve/main/VNCCS_QI2_PoseStudioV1.1.safetensors"
wget -c -O "$COMFY/models/loras/qwen21-nsfw-image-edit.safetensors" \
  "https://hf-mirror.com/RunningHubAI/rh-qwen-image-2.1-aio-nsfw-lora/resolve/main/Qwen-Image%202.1%20NSFW%20Image%20Edit.safetensors" \
  || wget -c -O "$COMFY/models/loras/qwen21-nsfw-image-edit.safetensors" \
  "https://hf-mirror.com/RunningHubAI/rh-qwen-image-2.1-aio-nsfw-lora/resolve/main/Qwen-Image-2.1%20NSFW%20Image%20Edit.safetensors"
# VNCCS node
if [[ ! -d "$COMFY/custom_nodes/ComfyUI_VNCCS_Utils" ]]; then
  git clone https://github.com/AHEKOT/ComfyUI_VNCCS_Utils.git "$COMFY/custom_nodes/ComfyUI_VNCCS_Utils"
fi
echo "DF_AFTER"; df -h "$COMFY" /root/autodl-tmp 2>/dev/null || df -h
ls -lh "$COMFY/models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors" \
       "$COMFY/models/text_encoders/qwen3vl_8b_int8_convrot.safetensors" \
       "$COMFY/models/vae/qwen_image_2.1_vae_bf16.safetensors" \
       "$COMFY/models/loras/VNCCS_QI2_PoseStudioV1.1.safetensors" \
       "$COMFY/models/loras/qwen21-nsfw-image-edit.safetensors"
