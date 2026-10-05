# 白素贞 / Bai Suzhen — makeup sheet

> **Cast lock 演员锁定：** 白素贞由固定演员林晚棠（lin_wantang）出演，脸和身体必须匹配 `ai-realistic-comic/library/cast/lin_wantang/actor.md` 与 `ref.png`，不得漂移（this role is played by the standing actor Lin Wantang; face and body must match the cast actor.md and ref.png, do not drift）。

Same adult woman in two bodies. Do not invent a second face.

## Face 脸

Even light skin, soft oval, clear black-brown eyes, natural brows, nude-pink lips. No gold irises, no crimson lips, no pearl-dot scale lace. The lock is `library/cast/lin_wantang/ref.png`. Late twenties.

浅色皮肤，柔和脸型，黑褐眼，自然眉，自然唇。不要浅金瞳，不要正红唇，不要鳞点妆。成年。

## Hair 发

Soft black hair loosely tied back, clean forehead. Not a period bun. Same hair on both bodies.

黑发松松束在脑后，额前干净。不要发髻。

## Bodies 身

Human form, rain bridge and the white-dress panels: two human legs, no tail, no fins. Black sheer wide-sleeve gauze over a white dress.

Serpent form, pavilion coil and the water panel: the same upper body, and from the hips down one thick pearl-white snake tail. Overlapping scales, faint teal glow on the belly scutes, thick blunt rounded tip. No legs, no feet, no caudal fin, no fluke.

人身：两条人腿，黑纱罩白衣。蛇身：腰以下只有一条珍珠白粗蛇尾，腹鳞淡青，尾尖圆钝，不是鱼尾。

## Costume and prop 衣

Ink-black translucent gauze, white wrapped dress, bare shoulders in the coil. She does not hold the oil-paper umbrella; Xu Xian holds it in the rain shot. Do not put that umbrella on her sheet.

## Palette and light 色与光

Black, white, pearl, teal moon, one warm lantern as a scene accent. The sheet itself is even grey studio light so the costume stays readable.

## Canvas

Two full-body passes, each 896×1200, then placed side by side. Final sheet 1792×1200. Left: human form. Right: serpent form. Same face. A single 1200×896 edit of both bodies collapsed into busts, so the runner generates each body alone and composites them.

<!-- GEN_HUMAN_START -->
One adult woman, full body, standing, facing the camera, both feet visible, plain neutral grey studio background, even soft light. Even light skin, black-brown eyes, nude-pink lips, no gold eyes, no scale-dot makeup. Soft black hair loosely tied back, clean forehead, no bun. Black sheer wide-sleeve gauze over a white dress. Two human legs. No tail. Delete the man, the umbrella, the rain, and the bridge. No second person. No text.

白素贞人身定妆。灰底棚拍全身正面，两条人腿，双脚入画。黑纱白衣，黑发松束，黑褐眼，自然唇。不要金瞳，不要发髻。删掉许仙、雨、伞、桥。不要蛇尾，不要文字。
<!-- GEN_HUMAN_END -->

<!-- NEG_HUMAN_START -->
man, second person, couple, embrace, umbrella, parasol, rain, bridge, pavilion, lake, throne, text, watermark, logo, extra fingers, deformed hands, child, minor, teen, cartoon, anime, fish tail, mermaid, fins, snake tail
<!-- NEG_HUMAN_END -->

<!-- GEN_SNAKE_START -->
One adult woman, front view, plain neutral grey studio background, even soft light. Keep her face, black-brown eyes, nude-pink lips, and black hair loosely tied back. No gold eyes, no crimson lips, no bun. Keep the black sheer gauze over a white bodice. Delete the man completely, including his bare foot, his robe, and the wooden box. Delete the pavilion and the lake.

Remove the long white skirt. From the waist down she has no human legs and no feet. One thick ivory-white snake tail grows out of her waist, coils once on the floor, and ends in a thick blunt rounded tip the same width as the tail, like a thumb, still attached. No pearl, no bead, no ball, no thin stem before the tip. Overlapping scales, faint teal glow on the belly scutes. One slim silver snake hairpin only. A few tiny white dots under the outer eye, not large cheek scales. The tail is her body.

白素贞蛇身。灰底正面。上身黑纱和白色抹胸，黑发松束，黑褐眼，自然唇。不要金瞳，不要发髻。腰以下没有白裙和人腿，只有一条从腰部长出的粗白蛇尾，盘一圈，尾尖又粗又圆，和尾巴一样粗，不要珍珠，不要细柄。删掉许仙。
<!-- GEN_SNAKE_END -->

<!-- NEG_SNAKE_START -->
man, second person, couple, embrace, umbrella, parasol, rain, bridge, pavilion, lake, lantern, wooden box, text, watermark, logo, extra fingers, deformed hands, child, minor, teen, cartoon, anime, fish tail, mermaid, fins, fin, caudal fin, fluke, two tails, human legs, feet, shoes, skirt, long dress, egg, sphere, pearl, bead, ball, lollipop, thin stem, detached tail tip, snake prop, hoop, two hairpins
<!-- NEG_SNAKE_END -->

<!-- GEN_PROMPT_START -->
Composite sheet. Left panel is the human-leg full-body pass. Right panel is the serpent full-body pass. Same face. Grey studio. No partner, no scenery, no text.
<!-- GEN_PROMPT_END -->

<!-- NEG_START -->
man, second person, couple, umbrella, rain, bridge, pavilion, fish tail, mermaid, fins, fluke, text, watermark
<!-- NEG_END -->

human_ref:
- library/samples/approved/crops/baisuzhen-human-rain.jpg
snake_ref:
- library/samples/approved/crops/baisuzhen-snake-pavilion.jpg
width: 896
height: 1200
sheet_width: 1792
sheet_height: 1200
