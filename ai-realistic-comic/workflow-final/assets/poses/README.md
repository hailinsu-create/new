# Pose library (Route C / VNCCS)

This folder vendors the **55 local curated pose JSONs** from
[Arekejoker/qwen21-nsfw-pose-skill](https://github.com/Arekejoker/qwen21-nsfw-pose-skill)
(`pose_library/local_user_poses`).

The full ~136-pose set (General / Ballet / VNCCS_Main / MySuperPose) is pulled
at restore time via ComfyUI `ComfyUI_VNCCS_Utils` repository refresh, or manually:

```bash
# after ComfyUI + VNCCS node are up
curl -X POST http://127.0.0.1:8188/vnccs/pose_library/repositories/refresh
```

Pinned node commit: see `../../pins.json`.
