#!/usr/bin/env python3
"""Phone-sized listing screenshots that match the real settings copy and overlay art."""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

OUT = Path("/workspace/docs/play/assets")
INK = (26, 18, 24, 255)
FOAM = (255, 247, 245, 255)
MIST = (196, 168, 176, 255)
AMBER = (242, 167, 184, 255)
PANEL = (31, 21, 32, 230)
YELLOW = (245, 196, 72, 255)
W, H = 1080, 1920


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc", size)


def rounded(draw, xy, r, fill):
    draw.rounded_rectangle(xy, radius=r, fill=fill)


def settings_shot() -> Image.Image:
    img = Image.new("RGB", (W, H), INK[:3])
    d = ImageDraw.Draw(img)
    d.text((72, 96), "旁窗", font=font(86), fill=FOAM[:3])
    d.text((72, 210), "关掉「演示陪伴语」并填入视觉 API。", font=font(28), fill=MIST[:3])
    d.text((72, 252), "默认使用稳定的 Qwen3-VL-8B。", font=font(28), fill=MIST[:3])

    rounded(d, (56, 310, 1024, 418), 28, PANEL)
    d.text((88, 328), "界面语言", font=font(22), fill=MIST[:3])
    d.text((88, 364), "跟随系统", font=font(32), fill=FOAM[:3])

    rounded(d, (56, 448, 1024, 728), 36, PANEL)
    d.text((88, 480), "解锁完整陪伴", font=font(34), fill=FOAM[:3])
    d.text((88, 538), "尚未解锁完整陪伴", font=font(26), fill=MIST[:3])
    d.text((88, 586), "一次购买约 $0.99，永久解锁真屏陪伴。", font=font(24), fill=MIST[:3])
    d.text((88, 624), "演示模式始终免费。", font=font(24), fill=MIST[:3])
    rounded(d, (88, 668, 992, 736), 24, AMBER)
    d.text((330, 684), "解锁完整陪伴（$0.99）", font=font(28), fill=INK[:3])

    rounded(d, (56, 768, 1024, 1088), 36, PANEL)
    d.text((88, 800), "隐私与合规", font=font(34), fill=FOAM[:3])
    d.text((88, 860), "隐私政策：启动陪伴前需同意", font=font(26), fill=MIST[:3])
    d.text((88, 908), "数据去向：你填写的视觉 API。", font=font(24), fill=MIST[:3])
    d.text((88, 948), "默认模型 Qwen3-VL-8B。HTTPS 传输。", font=font(24), fill=MIST[:3])

    rounded(d, (56, 1148, 1024, 1276), 28, YELLOW)
    d.text((300, 1190), "召唤小旁陪看屏幕", font=font(34), fill=INK[:3])
    rounded(d, (56, 1308, 1024, 1408), 28, (60, 44, 52))
    d.text((320, 1340), "仅演示悬浮窗（不看真屏）", font=font(28), fill=FOAM[:3])
    return img


def consent_shot() -> Image.Image:
    img = settings_shot().convert("RGB")
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 140))
    img = Image.alpha_composite(img.convert("RGBA"), overlay)
    d = ImageDraw.Draw(img)
    rounded(d, (80, 360, 1000, 1560), 36, (36, 26, 38, 255))
    d.text((120, 410), "使用前请知悉", font=font(40), fill=FOAM)
    lines = [
        "旁窗会截取当前屏幕画面，并发送到",
        "你自行配置的视觉 API 以生成陪伴语。",
        "",
        "• 截图不会保存到相册",
        "• 也不会上传到我们控制的服务器",
        "• API Key 仅存在本机",
        "• 锁屏时自动停止截屏与 API",
        "",
        "继续即表示你同意隐私政策。",
    ]
    y = 500
    for line in lines:
        d.text((120, y), line, font=font(28), fill=MIST)
        y += 48
    rounded(d, (120, 1320, 960, 1410), 24, AMBER)
    d.text((360, 1344), "同意并继续", font=font(30), fill=INK)
    rounded(d, (120, 1440, 960, 1520), 24, (60, 44, 52, 255))
    d.text((400, 1462), "查看政策", font=font(28), fill=FOAM)
    return img.convert("RGB")


def overlay_host() -> Image.Image:
    """A fake short-video / cart screen so the listing shows overlay on another app."""
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


def cut_mao(path: Path, size: int) -> Image.Image:
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
            if dist < 90:
                op[x, y] = (0, 0, 0, 0)
            else:
                op[x, y] = (r, g, b, 255)
    # Circle crop
    circle = Image.new("L", (w, h), 0)
    ImageDraw.Draw(circle).ellipse((8, 8, w - 8, h - 8), fill=255)
    out.putalpha(ImageChops.multiply(out.split()[3], circle))
    return out.resize((size, size), Image.Resampling.LANCZOS)


def paint_overlay(base: Image.Image, line: str, mao: Image.Image) -> Image.Image:
    img = base.convert("RGBA")
    d = ImageDraw.Draw(img)
    # Bubble
    bx0, by0, bx1, by1 = 48, 1180, 720, 1420
    rounded(d, (bx0, by0, bx1, by1), 28, PANEL)
    d.text((bx0 + 28, by0 + 22), "小旁", font=font(22), fill=AMBER)
    # wrap line
    y = by0 + 64
    buf = ""
    for ch in line:
        trial = buf + ch
        if font(26).getlength(trial) > (bx1 - bx0 - 56):
            d.text((bx0 + 28, y), buf, font=font(26), fill=FOAM[:3])
            y += 40
            buf = ch
        else:
            buf = trial
    if buf:
        d.text((bx0 + 28, y), buf, font=font(26), fill=FOAM[:3])
    ax, ay = 40, 1480
    ring = Image.new("RGBA", (mao.size[0] + 16, mao.size[1] + 16), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((0, 0, ring.size[0] - 1, ring.size[1] - 1), outline=AMBER, width=6)
    img.alpha_composite(ring, (ax - 8, ay - 8))
    img.alpha_composite(mao, (ax, ay))
    return img.convert("RGB")


def overlay_shot(mao: Image.Image) -> Image.Image:
    return paint_overlay(overlay_host(), "购物车比存款诚实。喜欢就买，犹豫就先晾着。", mao)


def overlay_closeup(mao: Image.Image) -> Image.Image:
    img = Image.new("RGB", (W, H), (18, 16, 22))
    d = ImageDraw.Draw(img)
    d.text((72, 80), "演示模式 · 不看真屏", font=font(28), fill=MIST[:3])
    big = mao.resize((560, 560), Image.Resampling.LANCZOS)
    img.paste(big, (260, 220), big)
    rounded(d, (80, 860, 1000, 1220), 32, PANEL)
    d.text((120, 900), "小旁", font=font(28), fill=AMBER)
    d.text((120, 960), "短视频一条接一条，像夜里不停的潮。", font=font(32), fill=FOAM[:3])
    d.text((120, 1020), "潮有涨有落，你也可以随时上岸。", font=font(32), fill=FOAM[:3])
    d.text((120, 1110), "长按角色换一句。锁屏会自己停。", font=font(26), fill=MIST[:3])
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    settings_shot().save(OUT / "screenshot_settings.png", "PNG")
    consent_shot().save(OUT / "screenshot_consent.png", "PNG")
    mao_path = OUT / "mao_face.png"
    if mao_path.exists():
        mao = cut_mao(mao_path, 420)
        overlay_shot(mao).save(OUT / "screenshot_overlay.png", "PNG")
        overlay_closeup(mao).save(OUT / "screenshot_overlay_closeup.png", "PNG")
        print("wrote listing screenshots including overlay")
    else:
        print("wrote listing screenshots (no mao_face.png, skipped overlay)")


if __name__ == "__main__":
    main()
