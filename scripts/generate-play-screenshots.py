#!/usr/bin/env python3
"""Phone-sized listing screenshots that match the real settings copy and overlay art."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

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


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    settings_shot().save(OUT / "screenshot_settings.png", "PNG")
    consent_shot().save(OUT / "screenshot_consent.png", "PNG")
    print("wrote listing screenshots")


if __name__ == "__main__":
    main()
