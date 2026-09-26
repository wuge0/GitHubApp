#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""参考 GitHub Octocat 视觉语言重画的猫头（原创几何，非官方图形）
特征：纯单色 / 扁平无渐变 / 圆润大头 / 小耳朵 / 大椭圆负形眼睛 / 无胡须无鼻子
"""
import os, math
from PIL import Image, ImageDraw

S, SS = 1024, 4
W = S * SS

# ---- 原始几何（Octocat 比例：头更宽更圆，耳朵更小）----
RAW_HEAD = (196, 300, 828, 812)
RAW_EAR_L = [(300, 370), (268, 178), (452, 318)]
RAW_EAR_R = [(724, 370), (756, 178), (532, 318)]
RAW_EYE_L = (348, 480, 452, 620)
RAW_EYE_R = (572, 480, 676, 620)

K, DY = 1.05, 18        # 让内容中心落在画布中心


def tf(p):
    return (512 + (p[0] - 512) * K, 512 + (p[1] - 512) * K + DY)


def sc(v):
    if isinstance(v, (int, float)):
        return v * SS
    if all(isinstance(p, (int, float)) for p in v):
        return tuple(p * SS for p in v)
    return [tuple(p * SS for p in t) for t in v]


HEAD = (tf((RAW_HEAD[0], RAW_HEAD[1])) + tf((RAW_HEAD[2], RAW_HEAD[3])))
EAR_L = [tf(p) for p in RAW_EAR_L]
EAR_R = [tf(p) for p in RAW_EAR_R]
EYE_L = tf((RAW_EYE_L[0], RAW_EYE_L[1])) + tf((RAW_EYE_L[2], RAW_EYE_L[3]))
EYE_R = tf((RAW_EYE_R[0], RAW_EYE_R[1])) + tf((RAW_EYE_R[2], RAW_EYE_R[3]))


def _down(m):
    return m.resize((S, S), Image.LANCZOS)


def cat_mask(with_eyes_hole=True):
    """猫头剪影；眼睛挖空成负形"""
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    d.ellipse(sc(HEAD), fill=255)
    d.polygon(sc(EAR_L), fill=255)
    d.polygon(sc(EAR_R), fill=255)
    if with_eyes_hole:
        d.ellipse(sc(EYE_L), fill=0)
        d.ellipse(sc(EYE_R), fill=0)
    return _down(m)


def eye_mask():
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    d.ellipse(sc(EYE_L), fill=255)
    d.ellipse(sc(EYE_R), fill=255)
    return _down(m)


def circle_mask(r=430):
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([(512 - r) * SS, (512 - r) * SS, (512 + r) * SS, (512 + r) * SS], fill=255)
    return _down(m)


def render_octo(bg, fg):
    """纯色底 + 单色猫头剪影"""
    c = Image.new("RGB", (S, S), bg)
    c.paste(Image.new("RGB", (S, S), fg), (0, 0), cat_mask())
    return c


def render_badge(bg, fg):
    """圆形徽章：底色 → 填圆 → 挖出猫头 → 点上眼睛"""
    c = Image.new("RGB", (S, S), bg)
    c.paste(Image.new("RGB", (S, S), fg), (0, 0), circle_mask())   # 黑色圆章
    c.paste(Image.new("RGB", (S, S), bg), (0, 0), cat_mask(False))  # 挖出猫头
    c.paste(Image.new("RGB", (S, S), fg), (0, 0), eye_mask())       # 眼睛
    return c


VARIANTS = [
    ("黑底白猫·GitHub风", (13, 17, 23), (240, 243, 246), "octo"),
    ("白底黑猫·GitHub风", (247, 248, 250), (16, 18, 22), "octo"),
    ("圆形徽章·白底",     (247, 248, 250), (16, 18, 22), "badge"),
    ("圆形徽章·黑底",     (13, 17, 23), (240, 243, 246), "badge"),
]

if __name__ == "__main__":
    out = "/workspace/GitHubApp/materials/cat-octo"
    os.makedirs(out, exist_ok=True)
    made = []
    for i, (name, bg, fg, mode) in enumerate(VARIANTS, 1):
        im = render_octo(bg, fg) if mode == "octo" else render_badge(bg, fg)
        fn = os.path.join(out, f"{i:02d}_{name}.png")
        im.save(fn)
        made.append((i, name, fn))
        print(f"{i} {name} -> {fn}")

    cols, cell, pad = 4, 240, 24
    rows = math.ceil(len(made) / cols)
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + pad + 34) + pad), (32, 36, 42))
    d = ImageDraw.Draw(sheet)
    for idx, (i, name, fn) in enumerate(made):
        r, c = divmod(idx, cols)
        x, y = pad + c * (cell + pad), pad + r * (cell + pad + 34)
        sheet.paste(Image.open(fn).resize((cell, cell), Image.LANCZOS), (x, y))
        d.text((x, y + cell + 9), f"#{i} {name}", fill=(235, 238, 242))
    sheet.save("/workspace/GitHubApp/cat-icons-GitHub风.png")
    print("\n对比图 -> cat-icons-GitHub风.png")
