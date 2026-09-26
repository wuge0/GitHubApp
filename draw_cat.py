#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""手绘极简黑白猫头图标（PIL 矢量绘制 + 4x 超采样抗锯齿）"""
import os, math, json
from PIL import Image, ImageDraw

S = 1024
SS = 4                      # 超采样倍数
W = S * SS

# ---- 1024 坐标系下的猫头几何 ----
_RAW_HEAD = (222, 310, 802, 810)                   # 头（椭圆）
_RAW_EAR_L = [(296, 392), (256, 128), (476, 322)]  # 左耳
_RAW_EAR_R = [(728, 392), (768, 128), (548, 322)]  # 右耳
_RAW_EYE_L = (354, 496, 442, 608)                  # 左眼（负形）
_RAW_EYE_R = (582, 496, 670, 608)
_RAW_NOSE = [(512, 678), (478, 636), (546, 636)]
_RAW_WHISKER_L = [((330, 660), (118, 618)), ((326, 690), (108, 700)), ((330, 716), (130, 782))]
_RAW_WHISKER_R = [((694, 660), (906, 618)), ((698, 690), (916, 700)), ((694, 716), (894, 782))]

# 整体放大并垂直居中（原内容中心 y≈469，画布中心 512）
K, DY, CX, CY = 1.06, 36, 512, 512


def tf(p):
    return (CX + (p[0] - CX) * K, CY + (p[1] - CY) * K + DY)


HEAD = (tf((_RAW_HEAD[0], _RAW_HEAD[1]))[0], tf((_RAW_HEAD[0], _RAW_HEAD[1]))[1],
        tf((_RAW_HEAD[2], _RAW_HEAD[3]))[0], tf((_RAW_HEAD[2], _RAW_HEAD[3]))[1])
EAR_L = [tf(p) for p in _RAW_EAR_L]
EAR_R = [tf(p) for p in _RAW_EAR_R]
EYE_L = (tf((_RAW_EYE_L[0], _RAW_EYE_L[1]))[0], tf((_RAW_EYE_L[0], _RAW_EYE_L[1]))[1],
         tf((_RAW_EYE_L[2], _RAW_EYE_L[3]))[0], tf((_RAW_EYE_L[2], _RAW_EYE_L[3]))[1])
EYE_R = (tf((_RAW_EYE_R[0], _RAW_EYE_R[1]))[0], tf((_RAW_EYE_R[0], _RAW_EYE_R[1]))[1],
         tf((_RAW_EYE_R[2], _RAW_EYE_R[3]))[0], tf((_RAW_EYE_R[2], _RAW_EYE_R[3]))[1])
NOSE = [tf(p) for p in _RAW_NOSE]
WHISKER_L = [(tf(a), tf(b)) for a, b in _RAW_WHISKER_L]
WHISKER_R = [(tf(a), tf(b)) for a, b in _RAW_WHISKER_R]


def sc(v):
    """坐标放大到超采样画布（支持 数值 / 数值元组 / 点列表）"""
    if isinstance(v, (int, float)):
        return v * SS
    if all(isinstance(p, (int, float)) for p in v):
        return tuple(p * SS for p in v)
    return [tuple(p * SS for p in t) for t in v]


def toward_center(pts, f):
    c = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
    return [(c[0] + (p[0] - c[0]) * f, c[1] + (p[1] - c[1]) * f) for p in pts]


def shrink_box(box, d):
    return (box[0] + d, box[1] + d, box[2] - d, box[3] - d)


def build_mask(style, whiskers):
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)

    if style == "solid":
        d.ellipse(sc(HEAD), fill=255)
        d.polygon(sc(EAR_L), fill=255)
        d.polygon(sc(EAR_R), fill=255)
        # 内耳 / 眼睛 / 鼻子 用背景色挖空
        d.polygon(sc(toward_center(EAR_L, 0.52)), fill=0)
        d.polygon(sc(toward_center(EAR_R, 0.52)), fill=0)
        d.ellipse(sc(EYE_L), fill=0)
        d.ellipse(sc(EYE_R), fill=0)
        d.polygon(sc(NOSE), fill=0)
    else:  # line 线稿
        ow = 34
        d.ellipse(sc(HEAD), fill=255)
        d.ellipse(sc(shrink_box(HEAD, ow)), fill=0)
        for ear in (EAR_L, EAR_R):
            d.polygon(sc(ear), fill=255)
            d.polygon(sc(toward_center(ear, 0.80)), fill=0)
        d.ellipse(sc(EYE_L), fill=255)
        d.ellipse(sc(EYE_R), fill=255)
        d.polygon(sc(NOSE), fill=255)

    body = m.resize((S, S), Image.LANCZOS)

    if not whiskers:
        return body
    wm = Image.new("L", (W, W), 0)
    dw = ImageDraw.Draw(wm)
    for segs in (WHISKER_L, WHISKER_R):
        for a, b in segs:
            dw.line([sc(a), sc(b)], fill=255, width=int(13 * SS))
            # 圆头端点
            for p in (a, b):
                r = 6.5 * SS
                dw.ellipse([sc(p[0]) - r, sc(p[1]) - r, sc(p[0]) + r, sc(p[1]) + r], fill=255)
    wm = wm.resize((S, S), Image.LANCZOS)
    return Image.merge("L", [ImageChop_lighter(body, wm)])


def ImageChop_lighter(a, b):
    from PIL import ImageChops
    return ImageChops.lighter(a, b)


def render(bg, fg, style="solid", whiskers=True):
    mask = build_mask(style, whiskers)
    canvas = Image.new("RGB", (S, S), bg)
    layer = Image.new("RGB", (S, S), fg)
    canvas.paste(layer, (0, 0), mask)
    return canvas.convert("RGB")


VARIANTS = [
    ("黑底白猫·带胡须", (13, 17, 23), (240, 243, 246), "solid", True),
    ("白底黑猫·带胡须", (247, 248, 250), (16, 18, 22), "solid", True),
    ("黑底白猫·极简",   (13, 17, 23), (240, 243, 246), "solid", False),
    ("白底黑猫·极简",   (247, 248, 250), (16, 18, 22), "solid", False),
    ("白底黑线稿",      (250, 250, 252), (16, 18, 22), "line",  True),
]

if __name__ == "__main__":
    out = "/workspace/GitHubApp/materials/cat-drawn"
    os.makedirs(out, exist_ok=True)
    made = []
    for i, (name, bg, fg, style, wh) in enumerate(VARIANTS, 1):
        im = render(bg, fg, style, wh)
        fn = os.path.join(out, f"{i:02d}_{name}.png")
        im.save(fn)
        made.append((i, name, fn))
        print(f"{i} {name} -> {fn}")

    # 对比图
    cols, cell, pad = 3, 320, 30
    import math as _m
    rows = _m.ceil(len(made) / cols)
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + pad + 36) + pad), (30, 34, 40))
    d = ImageDraw.Draw(sheet)
    for idx, (i, name, fn) in enumerate(made):
        r, c = divmod(idx, cols)
        x, y = pad + c * (cell + pad), pad + r * (cell + pad + 36)
        sheet.paste(Image.open(fn).resize((cell, cell), Image.LANCZOS), (x, y))
        d.text((x, y + cell + 10), f"#{i}  {name}", fill=(235, 238, 242))
    sheet.save("/workspace/GitHubApp/cat-icons-黑白.png")
    print("\n对比图 -> cat-icons-黑白.png")
