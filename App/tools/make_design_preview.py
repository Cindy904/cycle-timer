"""Render a static review board for the SwiftUI visual direction."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "DesignPreview.png"
S = 2
W, H = 1100, 1000
im = Image.new("RGB", (W * S, H * S), "#F3EDE3")
d = ImageDraw.Draw(im)
FONT = "/System/Library/Fonts/PingFang.ttc"
LATIN = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"


def f(size, latin=False):
    return ImageFont.truetype(LATIN if latin else FONT, int(size * S))


def rbox(x0, y0, x1, y1, fill, radius=0, outline=None, width=1):
    d.rounded_rectangle((x0*S, y0*S, x1*S, y1*S), radius=radius*S,
                        fill=fill, outline=outline, width=width*S)


def ellipse(x0, y0, x1, y1, fill):
    d.ellipse((x0*S, y0*S, x1*S, y1*S), fill=fill)


def text(x, y, value, size, fill="#303D2E", latin=False):
    d.text((x*S, y*S), value, font=f(size, latin), fill=fill)


def clock(cx, cy, size, accent):
    ellipse(cx-size/2, cy-size/2, cx+size/2, cy+size/2, "#FFFFFF")
    d.arc(((cx-size*.42)*S, (cy-size*.42)*S, (cx+size*.42)*S, (cy+size*.42)*S),
          25, 312, fill=accent, width=13*S)
    d.line((cx*S, cy*S, cx*S, (cy-size*.24)*S), fill=accent, width=8*S)
    d.line((cx*S, cy*S, (cx+size*.19)*S, (cy-size*.09)*S), fill=accent, width=8*S)
    ellipse(cx-7, cy-7, cx+7, cy+7, accent)


def person(cx, cy, accent):
    # Block-like, outline-free character to reflect the reference images.
    d.line(((cx-45)*S, (cy+42)*S, (cx-87)*S, (cy+92)*S), fill="#303D2E", width=19*S)
    d.line(((cx-27)*S, (cy+42)*S, (cx+14)*S, (cy+102)*S), fill="#303D2E", width=19*S)
    rbox(cx-66, cy-42, cx-17, cy+51, accent, 18)
    d.line(((cx-37)*S, (cy-6)*S, (cx+20)*S, (cy+15)*S), fill="#F7B99F", width=19*S)
    ellipse(cx-63, cy-93, cx-17, cy-47, "#F7B99F")
    ellipse(cx-68, cy-97, cx-18, cy-78, "#303D2E")


def phone(x, y, title):
    rbox(x, y, x+420, y+895, "#FFFFFF", 43)
    rbox(x+11, y+11, x+409, y+884, "#FEFBF6", 34)
    rbox(x+158, y+18, x+263, y+40, "#303D2E", 12)
    text(x+36, y+20, "9:41", 15, "#303D2E", True)
    text(x+36, y+60, title, 31, "#303D2E")


phone(95, 52, "循环计时")
for left, label, detail, icon_color, icon_bg in [
    (127, "单步骤重复", "45秒 × 8次", "#14A89C", "#E3F5F0"),
    (310, "多步骤循环", "（40秒+20秒）×5组", "#219EBF", "#E3F5FA"),
]:
    rbox(left, 170, left+173, 340, "#FFFFFF", 19, "#E6D9C4")
    rbox(left+17, 187, left+63, 233, icon_bg, 13)
    if left == 127:
        d.arc(((left+29)*S, 199*S, (left+51)*S, 221*S), 45, 320, fill=icon_color, width=3*S)
        d.polygon(((left+50)*S, 199*S, (left+53)*S, 208*S, (left+44)*S, 205*S), fill=icon_color)
    else:
        for offset in (0, 6, 12):
            d.line(((left+28)*S, (201+offset)*S, (left+51)*S, (201+offset)*S), fill=icon_color, width=3*S)
    text(left+17, 276, label, 16)
    text(left+17, 308, detail, 12, "#667061")
text(132, 380, "我的项目", 23)
text(424, 388, "+ 新建", 14, "#577843")
rbox(127, 425, 483, 570, "#FFFFFF", 21, "#E6D9C4")
text(148, 454, "还没有项目", 20)
text(148, 494, "点击「新建」，创建自己的计时项目。", 12, "#667061")

phone(585, 52, "")
text(620, 120, "‹", 35)
text(754, 132, "第 1 / 1 套", 14)
text(920, 132, "数字", 14, "#577843")
clock(795, 329, 215, "#7A9E5E")
rbox(755, 476, 848, 507, "#EDF3E5", 15)
text(771, 482, "计时中", 14, "#7A9E5E")
text(755, 529, "当前步骤", 23)
text(717, 568, "00:45", 72, "#303D2E", True)
text(721, 665, "第 1 组 · 本步骤 1 / 8", 14, "#667061")
rbox(618, 715, 972, 720, "#E6D9C4", 3)
rbox(618, 715, 675, 720, "#7A9E5E", 3)
text(620, 735, "已完成 0 / 8 个计时段", 12, "#667061")
text(620, 767, "接下来：步骤间隔", 14)
rbox(618, 808, 972, 860, "#7A9E5E", 18)
text(766, 819, "暂停", 19, "#1F2E1C")

im.resize((W, H), Image.Resampling.LANCZOS).save(OUT, optimize=True)
print(OUT)
