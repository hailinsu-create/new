# Codex CLI 资产打分入口

这份文件是演员资产穿衣底板和去衣两段的唯一打分标准。门禁文案、八项定义、硬门规则由 Codex CLI 执行，并只在这里维护。

`autodl/run_cast_body_two_stage.py` 只调用 Codex CLI：`codex exec --skip-git-repo-check --ephemeral --color never -C <目录> -s workspace-write -i <定妆 ref.png> -i <待打分图> -`。标准输入只点名本文件、演员、视图和阶段。脚本不复述下面的规则，不另写一套八项，也不调用 OpenCode vision。没有 `codex` 就 `SystemExit`，打印 `CODEX_CLI_MISSING`。未登录打印 `CODEX_CLI_LOGGED_OUT`。本文件缺失打印 `CODEX_SCORE_ENTRY_MISSING`。三种情况都不改走别的打分。

不要生成图像。不要改文件。不要改写或摘要替换本文件。第一张图是这位成年演员的定妆锁脸。只给第二张图打分。这是一张成年身体模板，不是情节，也不是两个人。全身，头和双脚都在画面内，纯色背景，仅限成年人。

八项等权，各 0–10：identity, distinction, interaction, aesthetics, anatomy, wardrobe, motif, photoreal。interaction means the pose is a stable turnaround, not a story pose. mean is their equal average. gates is [] or H6 for a minor look, H4 for Elena's ears or green eyes or glasses or Adrian missing ears or holding a weapon, H7 for malformed limbs, FEET if a foot is cut off.

只输出一个 JSON 对象：

{"gates":[],"period_hair":false,"period_makeup":false,"eyes_black_brown":false,"identity":0,"distinction":0,"interaction":0,"aesthetics":0,"anatomy":0,"wardrobe":0,"motif":0,"photoreal":0,"mean":0,"note":"一句"}

## 林晚棠、顾承安

Nude template for Lin or Gu. Identity is facial features, face shape, skin tone, and body type. Costume hair and makeup must be gone: no hair bun, no hairpins, no forehead ornament, no heavy eye makeup, no crimson lips. Hair is natural black-brown. Makeup is light or bare. Eyes are normal black-brown. Do not deduct identity for that change. Do deduct, and set period_hair or period_makeup true, if the bun, ornaments, heavy makeup, or red lips remain. Set eyes_black_brown true only when the irises read black-brown.

背面，且演员是林晚棠或顾承安：Back view: do not fail identity because the face is hidden. Eyes may be unseen.

## 伊莲·沃斯

Keep Elena's soft brown wavy hair loosely pulled back, clear blue-grey eyes, and human ears. No glasses. Do not give her pointed ears, green eyes, auburn hair, or amber eyes. period_hair and period_makeup stay false. eyes_black_brown stays false because her eyes are blue-grey.

## 阿德里安·凯恩

Keep Adrian's dark hair, pale blue-grey eyes, and pointed ears. No weapon. period_hair and period_makeup stay false. eyes_black_brown stays false.

## 阶段 clothed

This is a clothed full-body plate, not a nude. The first image is the new frontal lock. Identity below 9 means the result face does not match that lock. Do not accept the retired gold eyes, crimson lips, period bun, auburn hair, or amber eyes. Wardrobe below 9 means the named everyday clothes are missing, or a period costume replaced them. Nudity is a wardrobe failure on this stage. The plate must clear every content score. Resolution is the only exemption.

## 阶段 pass1

Pass 1 may change only clothes, hair, and makeup on the clothed plate. The makeup reference is the current lock face. Identity below 9 means the face was redrawn: face shape, features, or skin tone moved. Do not mark identity below 9 because the instructed hair or makeup changed. Wardrobe below 9 means cloth remains on the chest, abdomen, hips, or legs. Do not trade a locked face for leftover clothes. Pass 1 must clear every content score. Resolution is the only exemption: do not add a penalty, and do not waive a content score, only because the frame is small. Pixel count is pass 2. Wrong face, pose, anatomy, wardrobe, likeness, or motif still scores below 9.

Nude pass requires every garment gone. If cloth remains on the chest, abdomen, hips, or legs, wardrobe is below 8.

## 阶段 pass2

Pass 2 is a same-seed light upscale. Content must stay the pass-1 plate. Lower a score when the upscale changes the face, hair, makeup, pose, body, or anatomy.

Nude pass requires every garment gone. If cloth remains on the chest, abdomen, hips, or legs, wardrobe is below 8.
