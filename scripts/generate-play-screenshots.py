#!/usr/bin/env python3
"""Phone-sized listing screenshots that match the companion home and 96dp overlay."""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

OUT = Path("/workspace/docs/play/assets")
INK = (26, 18, 24, 255)
FOAM = (255, 247, 245, 255)
MIST = (196, 168, 176, 255)
AMBER = (242, 167, 184, 255)
PANEL = (31, 21, 32, 230)
YELLOW = (242, 167, 184, 255)
W, H = 1080, 1920
# 96dp on a 360dp-wide 1080px composite ≈ 288px. 48dp close ≈ 144px.
OVERLAY_FACE = 288
OVERLAY_CLOSE = 144


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc", size)


def rounded(draw, xy, r, fill):
    draw.rounded_rectangle(xy, radius=r, fill=fill)


def settings_shot() -> Image.Image:
    img = Image.new("RGB", (W, H), INK[:3])
    d = ImageDraw.Draw(img)
    d.text((72, 80), "旁窗", font=font(86), fill=FOAM[:3])
    d.text((72, 190), "屏幕边的国风伴侣。演示免费；", font=font(28), fill=MIST[:3])
    d.text((72, 232), "完整陪伴会看你的屏幕。", font=font(28), fill=MIST[:3])

    face_path = OUT / "moxi_face.png"
    if face_path.exists():
        face = cut_face(face_path, 280)
        img.paste(face, (400, 300), face)

    d.text((72, 620), "小旁在休息。先试免费演示，", font=font(26), fill=MIST[:3])
    d.text((72, 662), "或解锁后开始完整陪伴。", font=font(26), fill=MIST[:3])

    rounded(d, (56, 740, 1024, 868), 28, YELLOW)
    d.text((400, 780), "演示召唤", font=font(36), fill=INK[:3])
    rounded(d, (56, 900, 1024, 1012), 28, (60, 44, 52))
    d.text((400, 934), "完整陪伴", font=font(32), fill=FOAM[:3])
    rounded(d, (56, 1040, 1024, 1144), 28, (40, 28, 36))
    d.text((360, 1072), "让小旁先休息", font=font(28), fill=MIST[:3])
    d.text((340, 1220), "完整陪伴设置", font=font(26), fill=AMBER)
    return img


def consent_shot() -> Image.Image:
    img = settings_shot().convert("RGB")
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 140))
    img = Image.alpha_composite(img.convert("RGBA"), overlay)
    d = ImageDraw.Draw(img)
    rounded(d, (80, 320, 1000, 1600), 36, (36, 26, 38, 255))
    d.text((120, 370), "使用前请知悉", font=font(40), fill=FOAM)
    lines = [
        "旁窗会截取当前屏幕画面，并发送到",
        "你自行配置的视觉 API 以生成陪伴语。",
        "",
        "• 截图不会保存到相册",
        "• 也不会上传到我们控制的服务器",
        "• API Key 仅存在本机",
        "• 锁屏时真正停止截屏（释放录屏）",
        "",
        "继续即表示你同意隐私政策。",
    ]
    y = 460
    for line in lines:
        d.text((120, y), line, font=font(28), fill=MIST)
        y += 48
    rounded(d, (120, 1320, 960, 1410), 24, AMBER)
    d.text((360, 1344), "同意并继续", font=font(30), fill=INK)
    rounded(d, (120, 1440, 960, 1520), 24, (60, 44, 52, 255))
    d.text((400, 1462), "查看政策", font=font(28), fill=FOAM)
    return img.convert("RGB")


def overlay_host() -> Image.Image:
    img = Image.new("RGB", (W, H), (18, 16, 22))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, 88), fill=(12, 10, 14))
    d.text((36, 28), "9:41", font=font(28), fill=FOAM[:3])
    d.text((860, 28), "4G  81%", font=font(24), fill=MIST[:3])

    d.rectangle((0, 88, W, 1480), fill=(8, 8, 10))
    d.text((48, 140), "夜市短视频", font=font(26), fill=MIST[:3])
    d.text((48, 200), "同一支舞的第十八个翻拍", font=font(40), fill=FOAM[:3])
    rounded(d, (48, 280, 1032, 980), 28, (42, 28, 36))
    d.text((80, 600), "购物车还差 ¥12.8 凑券", font=font(36), fill=AMBER)
    d.text((80, 670), "结不结账，听心里那一下。", font=font(28), fill=MIST[:3])

    rounded(d, (48, 1020, 320, 1100), 20, (60, 44, 52))
    d.text((88, 1044), "不感兴趣", font=font(24), fill=FOAM[:3])
    rounded(d, (360, 1020, 700, 1100), 20, YELLOW)
    d.text((430, 1044), "去结算", font=font(26), fill=INK[:3])

    d.rectangle((0, 1480, W, H), fill=(14, 12, 16))
    for i, lab in enumerate(["首页", "朋友", "拍", "消息", "我"]):
        d.text((70 + i * 210, 1580), lab, font=font(26), fill=MIST[:3])
    return img


def cut_face(path: Path, size: int) -> Image.Image:
    src = Image.open(path).convert("RGBA")
    pix = src.load()
    w, h = src.size
    key = pix[2, 2][:3]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            dist = abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2])
            if a < 16 or dist < 36:
                op[x, y] = (0, 0, 0, 0)
            else:
                op[x, y] = (r, g, b, 255)
    circle = Image.new("L", (w, h), 0)
    ImageDraw.Draw(circle).ellipse((8, 8, w - 8, h - 8), fill=255)
    out.putalpha(ImageChops.multiply(out.split()[3], circle))
    return out.resize((size, size), Image.Resampling.LANCZOS)


def paint_overlay(base: Image.Image, line: str, face: Image.Image) -> Image.Image:
    img = base.convert("RGBA")
    d = ImageDraw.Draw(img)
    bx0, by0, bx1, by1 = 48, 1180, 640, 1400
    rounded(d, (bx0, by0, bx1, by1), 24, PANEL)
    d.text((bx0 + 24, by0 + 18), "小旁", font=font(22), fill=AMBER)
    y = by0 + 58
    buf = ""
    for ch in line:
        trial = buf + ch
        if font(26).getlength(trial) > (bx1 - bx0 - 48):
            d.text((bx0 + 24, y), buf, font=font(26), fill=FOAM[:3])
            y += 38
            buf = ch
        else:
            buf = trial
    if buf:
        d.text((bx0 + 24, y), buf, font=font(26), fill=FOAM[:3])
    ax, ay = 48, 1488
    ring = Image.new("RGBA", (face.size[0] + 12, face.size[1] + 12), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((0, 0, ring.size[0] - 1, ring.size[1] - 1), outline=AMBER, width=5)
    img.alpha_composite(ring, (ax - 6, ay - 6))
    img.alpha_composite(face, (ax, ay))
    # 48dp close chip on the start/outer corner of the 96dp face (not a device photo).
    cx = ax - 6
    cy = ay - 6
    d.ellipse((cx, cy, cx + OVERLAY_CLOSE, cy + OVERLAY_CLOSE), fill=(10, 6, 8, 240), outline=(255, 232, 238, 255), width=5)
    pad = OVERLAY_CLOSE // 3
    d.line((cx + pad, cy + pad, cx + OVERLAY_CLOSE - pad, cy + OVERLAY_CLOSE - pad), fill=FOAM, width=6)
    d.line((cx + OVERLAY_CLOSE - pad, cy + pad, cx + pad, cy + OVERLAY_CLOSE - pad), fill=FOAM, width=6)
    return img.convert("RGB")


def overlay_shot(face: Image.Image) -> Image.Image:
    return paint_overlay(overlay_host(), "购物车比存款诚实。喜欢就买，犹豫就先晾着。", face)


def overlay_closeup(face: Image.Image) -> Image.Image:
    img = Image.new("RGB", (W, H), (18, 16, 22))
    d = ImageDraw.Draw(img)
    d.text((72, 80), "演示模式 · 不看真屏", font=font(28), fill=MIST[:3])
    big = face.resize((420, 420), Image.Resampling.LANCZOS)
    img.paste(big, (330, 260), big)
    # Close chip matching the 48dp overlay control (composite, not a device photo).
    d.ellipse((250, 230, 250 + OVERLAY_CLOSE, 230 + OVERLAY_CLOSE), fill=(10, 6, 8), outline=(255, 232, 238), width=5)
    d.line((250 + 40, 230 + 40, 250 + OVERLAY_CLOSE - 40, 230 + OVERLAY_CLOSE - 40), fill=FOAM[:3], width=6)
    d.line((250 + OVERLAY_CLOSE - 40, 230 + 40, 250 + 40, 230 + OVERLAY_CLOSE - 40), fill=FOAM[:3], width=6)
    rounded(d, (80, 860, 1000, 1280), 32, PANEL)
    d.text((120, 900), "小旁", font=font(28), fill=AMBER)
    d.text((120, 960), "短视频一条接一条，像夜里不停的潮。", font=font(32), fill=FOAM[:3])
    d.text((120, 1020), "潮有涨有落，你也可以随时上岸。", font=font(32), fill=FOAM[:3])
    d.text((120, 1110), "点按开关气泡。长按换一句。", font=font(26), fill=MIST[:3])
    d.text((120, 1160), "右上角让小旁休息。锁屏会真正停截屏。", font=font(26), fill=MIST[:3])
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    settings_shot().save(OUT / "screenshot_settings.png", "PNG")
    consent_shot().save(OUT / "screenshot_consent.png", "PNG")
    face_path = OUT / "moxi_face.png"
    if face_path.exists():
        face = cut_face(face_path, OVERLAY_FACE)
        overlay_shot(face).save(OUT / "screenshot_overlay.png", "PNG")
        overlay_closeup(face).save(OUT / "screenshot_overlay_closeup.png", "PNG")
        print("wrote listing screenshot composites (96dp avatar, 48dp close; not device photos)")
    else:
        print("wrote listing screenshots (no moxi_face.png, skipped overlay)")


if __name__ == "__main__":
    main()
