#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""为 GitHubApp 生成 iOS AppIcon 全套尺寸（无 alpha 通道）v2"""
import os, json, math
from PIL import Image, ImageDraw, ImageFilter

OUT = "/workspace/GitHubApp/GitHubApp/Assets.xcassets/AppIcon.appiconset"
os.makedirs(OUT, exist_ok=True)

S = 1024                      # 设计画布
BG_TOP = (22, 27, 34)         # #161B22
BG_BOT = (13, 17, 23)         # #0D1117
LINE   = (230, 237, 243)      # #E6EDF3
GREEN  = (63, 185, 80)        # #3FB950
BLUE   = (31, 111, 235)       # #1F6FEB


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def base(size):
    """渐变背景 + 中心蓝色光晕"""
    img = Image.new("RGB", (size, size))
    px = img.load()
    c = (size - 1) / 2.0
    for y in range(size):
        t = y / (size - 1)
        row = lerp(BG_TOP, BG_BOT, t)
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size * 0.72)
            g = max(0.0, 1.0 - d)
            g = g * g * 0.30           # 光晕强度
            px[x, y] = tuple(
                min(255, int(row[i] + (BLUE[i] - row[i]) * g)) for i in range(3)
            )
    return img


def bezier(p0, p1, p2, p3, n=300):
    pts = []
    for i in range(n + 1):
        t = i / n
        m = 1 - t
        x = (m**3 * p0[0] + 3 * m * m * t * p1[0] + 3 * m * t * t * p2[0] + t**3 * p3[0])
        y = (m**3 * p0[1] + 3 * m * m * t * p1[1] + 3 * m * t * t * p2[1] + t**3 * p3[1])
        pts.append((x, y))
    return pts


def thick_curve(d, pts, width, color):
    """把曲线画成闭合多边形（沿法线向两侧偏移），避免折线接缝毛刺"""
    n = len(pts)
    left, right = [], []
    w = width / 2.0
    for i, (x, y) in enumerate(pts):
        if i == 0:
            dx, dy = pts[1][0] - x, pts[1][1] - y
        elif i == n - 1:
            dx, dy = x - pts[i - 1][0], y - pts[i - 1][1]
        else:
            dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L, dx / L
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    d.polygon(left + right[::-1], fill=color)


def render(size):
    """画图标：git 分支合并图（主干 + 分支 + 合并节点）"""
    k = size / 1024.0
    img = base(size)
    d = ImageDraw.Draw(img)

    def P(x, y):
        return (x * k, y * k)

    lw = 38 * k
    # 主干：顶部圆帽 → 绿色合并节点（无尾部）
    d.line([P(400, 236), P(400, 700)], fill=LINE, width=int(round(lw)))
    r_cap = lw / 2
    top = P(400, 236)
    d.ellipse([top[0] - r_cap, top[1] - r_cap, top[0] + r_cap, top[1] + r_cap], fill=LINE)

    # 分支：从主干分出，绕右侧再合回主干
    b0, b1, b2, b3 = P(400, 428), P(704, 474), P(704, 654), P(400, 700)
    thick_curve(d, bezier(b0, b1, b2, b3), lw, LINE)

    # 分支上的提交节点（贝塞尔 t=0.5 处）
    apex = ((b0[0] + 3 * b1[0] + 3 * b2[0] + b3[0]) / 8,
            (b0[1] + 3 * b1[1] + 3 * b2[1] + b3[1]) / 8)
    r = 60 * k
    d.ellipse([apex[0] - r, apex[1] - r, apex[0] + r, apex[1] + r], fill=LINE)

    # 合并节点（绿色，稍大）
    R = 76 * k
    d.ellipse([b3[0] - R, b3[1] - R, b3[0] + R, b3[1] + R], fill=GREEN)
    return img


master = render(S)
master.save("/workspace/GitHubApp/icon-preview.png")

# 尺寸表：(idiom, size(pt), scale, filename)
SPEC = [
    ("iphone", 20, 2, "icon-20@2x.png"),
    ("iphone", 20, 3, "icon-20@3x.png"),
    ("iphone", 29, 2, "icon-29@2x.png"),
    ("iphone", 29, 3, "icon-29@3x.png"),
    ("iphone", 40, 2, "icon-40@2x.png"),
    ("iphone", 40, 3, "icon-40@3x.png"),
    ("iphone", 60, 2, "icon-60@2x.png"),
    ("iphone", 60, 3, "icon-60@3x.png"),
    ("ipad", 20, 1, "icon-20.png"),
    ("ipad", 20, 2, "icon-20-ipad@2x.png"),
    ("ipad", 29, 1, "icon-29.png"),
    ("ipad", 29, 2, "icon-29-ipad@2x.png"),
    ("ipad", 40, 1, "icon-40.png"),
    ("ipad", 40, 2, "icon-40-ipad@2x.png"),
    ("ipad", 76, 1, "icon-76.png"),
    ("ipad", 76, 2, "icon-76@2x.png"),
    ("ipad", 83.5, 2, "icon-83.5@2x.png"),
    ("ios-marketing", 1024, 1, "icon-1024.png"),
]

images = []
for idiom, pt, scale, fn in SPEC:
    px = int(round(pt * scale))
    im = master.resize((px, px), Image.LANCZOS).convert("RGB")   # 去掉 alpha
    im.save(os.path.join(OUT, fn), optimize=True)
    images.append({"idiom": idiom, "size": f"{pt}x{pt}", "scale": f"{scale}x", "filename": fn})

contents = {
    "images": images,
    "info": {"author": "xcode", "version": 1},
}
with open(os.path.join(OUT, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

print("OK ->", OUT)
print("files:", len(images) + 1)
