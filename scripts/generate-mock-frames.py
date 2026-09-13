#!/usr/bin/env python3
"""Phone-sized demo frames that look like real app screens (not solid rectangles)."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/workspace")
OUTS = [
    ROOT / "assets/mock",
    ROOT / "android/app/src/main/assets/mock",
]
W, H = 720, 1280
FOAM = (255, 247, 245)
MIST = (196, 168, 176)
INK = (18, 14, 20)
PANEL = (36, 26, 38)
AMBER = (242, 167, 184)


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in (
        "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def rounded(d: ImageDraw.ImageDraw, xy, r, fill):
    d.rounded_rectangle(xy, radius=r, fill=fill)


def chrome(d: ImageDraw.ImageDraw, title: str) -> None:
    d.rectangle((0, 0, W, 72), fill=(12, 10, 14))
    d.text((28, 22), "9:41", font=font(22), fill=FOAM)
    d.text((560, 22), "4G  81%", font=font(20), fill=MIST)
    d.rectangle((0, 72, W, 148), fill=(22, 16, 24))
    d.text((28, 94), title, font=font(30), fill=FOAM)


def save(name: str, img: Image.Image) -> None:
    for folder in OUTS:
        folder.mkdir(parents=True, exist_ok=True)
        img.save(folder / name, "PNG")


def feed() -> Image.Image:
    img = Image.new("RGB", (W, H), (8, 8, 10))
    d = ImageDraw.Draw(img)
    chrome(d, "夜市短视频")
    rounded(d, (24, 180, 696, 860), 28, (42, 28, 36))
    d.text((48, 460), "同一支舞的第十八个翻拍", font=font(34), fill=FOAM)
    d.text((48, 520), "又一条同款舞蹈", font=font(24), fill=MIST)
    rounded(d, (48, 900, 240, 980), 20, PANEL)
    d.text((78, 924), "不感兴趣", font=font(22), fill=FOAM)
    rounded(d, (268, 900, 500, 980), 20, AMBER)
    d.text((330, 924), "下一条", font=font(22), fill=INK)
    d.rectangle((0, 1120, W, H), fill=(14, 12, 16))
    for i, lab in enumerate(["首页", "朋友", "拍", "消息", "我"]):
        d.text((48 + i * 136, 1180), lab, font=font(22), fill=MIST)
    return img


def chat() -> Image.Image:
    img = Image.new("RGB", (W, H), (16, 18, 22))
    d = ImageDraw.Draw(img)
    chrome(d, "微信 · 置顶群")
    rounded(d, (24, 180, 520, 300), 22, (47, 59, 70))
    d.text((48, 210), "老板：在吗？急！", font=font(28), fill=FOAM)
    d.text((48, 252), "下午三点前把表发我", font=font(22), fill=MIST)
    rounded(d, (200, 340, 696, 460), 22, (58, 170, 116))
    d.text((228, 370), "我在看，十分钟内回。", font=font(26), fill=INK)
    rounded(d, (24, 500, 500, 620), 22, (47, 59, 70))
    d.text((48, 530), "红点 18", font=font(26), fill=AMBER)
    d.text((48, 572), "先看完眼前这一条。", font=font(22), fill=MIST)
    d.rectangle((0, 1160, W, H), fill=(22, 24, 28))
    d.text((40, 1204), "发送消息…", font=font(24), fill=MIST)
    return img


def shop() -> Image.Image:
    img = Image.new("RGB", (W, H), (20, 16, 14))
    d = ImageDraw.Draw(img)
    chrome(d, "购物车结算")
    rounded(d, (24, 180, 696, 360), 24, PANEL)
    d.text((48, 210), "亚麻衬衫 × 1", font=font(28), fill=FOAM)
    d.text((48, 260), "¥89.00", font=font(24), fill=MIST)
    rounded(d, (24, 392, 696, 572), 24, PANEL)
    d.text((48, 422), "陶瓷杯 × 2", font=font(28), fill=FOAM)
    d.text((48, 472), "凑单还差 ¥12.8", font=font(24), fill=AMBER)
    rounded(d, (24, 980, 696, 1100), 24, AMBER)
    d.text((240, 1020), "去结算  ¥186.20", font=font(28), fill=INK)
    return img


def game() -> Image.Image:
    img = Image.new("RGB", (W, H), (10, 12, 22))
    d = ImageDraw.Draw(img)
    chrome(d, "排位赛匹配中")
    d.ellipse((220, 280, 500, 560), outline=AMBER, width=8)
    d.text((250, 390), "匹配中", font=font(40), fill=FOAM)
    d.text((200, 620), "你已经连跪三把", font=font(30), fill=AMBER)
    d.text((180, 680), "段位是数字，手感是此刻", font=font(24), fill=MIST)
    rounded(d, (160, 900, 560, 1000), 24, (60, 44, 120))
    d.text((250, 930), "取消匹配", font=font(28), fill=FOAM)
    return img


def note() -> Image.Image:
    img = Image.new("RGB", (W, H), (20, 24, 20))
    d = ImageDraw.Draw(img)
    chrome(d, "备忘录")
    items = [
        "明天早上 7:30 开会",
        "把旁窗商店图换成真机",
        "回复置顶群",
        "买菜：豆腐 青菜",
    ]
    y = 190
    for item in items:
        rounded(d, (24, y, 696, y + 120), 20, (30, 40, 32))
        d.ellipse((48, y + 44, 80, y + 76), outline=AMBER, width=3)
        d.text((108, y + 42), item, font=font(26), fill=FOAM)
        y += 140
    return img


def main() -> None:
    save("feed.png", feed())
    save("chat.png", chat())
    save("shop.png", shop())
    save("game.png", game())
    save("note.png", note())
    print("wrote mock frames")


if __name__ == "__main__":
    main()
