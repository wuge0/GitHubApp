#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 Pixabay 猫素材合成成 iOS 图标：去背景 → 裁主体 → 配底色 → 出 1024 母版"""
import json, os, math, sys
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

CAT = "/workspace/GitHubApp/materials/cat"
COMPOSED = os.path.join(CAT, "composed")
os.makedirs(COMPOSED, exist_ok=True)
S = 1024

DARK = ((22, 27, 34), (13, 17, 23), (31, 111, 235))   # 顶 / 底 / 光晕
LIGHT = ((245, 247, 250), (222, 228, 236), (88, 166, 255))


def gradient(size, top, bot, glow):
    img = Image.new("RGB", (size, size))
    px = img.load()
    c = (size - 1) / 2.0
    for y in range(size):
        t = y / (size - 1)
        row = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size * 0.72)
            g = max(0.0, 1.0 - d) ** 2 * 0.28
            px[x, y] = tuple(min(255, int(row[i] + (glow[i] - row[i]) * g)) for i in range(3))
    return img


def strip_bg(im, tol=60):
    """没有 alpha 就按四角底色做洪水填充去背景"""
    rgba = im.convert("RGBA")
    a = np.array(rgba)
    if (a[..., 3] < 250).mean() > 0.05:
        return rgba
    rgb = a[..., :3].astype(int)
    h, w = rgb.shape[:2]
    corners = np.array([rgb[1, 1], rgb[1, -2], rgb[-2, 1], rgb[-2, -2]])
    bg = corners.mean(axis=0)
    diff = np.abs(rgb - bg).sum(axis=2)
    seen = np.zeros((h, w), bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if diff[y, x] < tol and not seen[y, x]:
                seen[y, x] = True; dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if diff[y, x] < tol and not seen[y, x]:
                seen[y, x] = True; dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and diff[ny, nx] < tol:
                seen[ny, nx] = True; dq.append((ny, nx))
    out = a.copy()
    out[..., 3] = np.where(seen, 0, 255)
    return Image.fromarray(out, "RGBA")


def compose(path, fill=0.74):
    src = strip_bg(Image.open(path))
    bbox = src.split()[-1].getbbox()
    if not bbox:
        return None
    sub = src.crop(bbox)
    sw, sh = sub.size
    target = int(S * fill)
    k = target / max(sw, sh)
    sub = sub.resize((max(1, int(sw * k)), max(1, int(sh * k))), Image.LANCZOS)

    # 主体亮度决定底色（深色主体配浅底，浅色主体配深底）
    ar = np.array(sub)
    m = ar[..., 3] > 32
    if m.any():
        lum = float(ar[..., :3][m].mean())
    else:
        lum = 128.0
    top, bot, glow = LIGHT if lum < 95 else DARK
    canvas = gradient(S, top, bot, glow)

    # 轻微投影，增强立体感
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    off = ((S - sub.size[0]) // 2, (S - sub.size[1]) // 2 + 12)
    mask = sub.split()[-1].filter(ImageFilter.GaussianBlur(18))
    shadow.paste((0, 0, 0, 110), (off[0], off[1] + 6), mask)
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB")

    pos = ((S - sub.size[0]) // 2, (S - sub.size[1]) // 2)
    canvas.paste(sub, pos, sub)
    return canvas


def write_iconset(master, out_dir):
    """从母版生成 18 个尺寸 + Contents.json"""
    os.makedirs(out_dir, exist_ok=True)
    SPEC = [
        ("iphone", 20, 2, "icon-20@2x.png"), ("iphone", 20, 3, "icon-20@3x.png"),
        ("iphone", 29, 2, "icon-29@2x.png"), ("iphone", 29, 3, "icon-29@3x.png"),
        ("iphone", 40, 2, "icon-40@2x.png"), ("iphone", 40, 3, "icon-40@3x.png"),
        ("iphone", 60, 2, "icon-60@2x.png"), ("iphone", 60, 3, "icon-60@3x.png"),
        ("ipad", 20, 1, "icon-20.png"), ("ipad", 20, 2, "icon-20-ipad@2x.png"),
        ("ipad", 29, 1, "icon-29.png"), ("ipad", 29, 2, "icon-29-ipad@2x.png"),
        ("ipad", 40, 1, "icon-40.png"), ("ipad", 40, 2, "icon-40-ipad@2x.png"),
        ("ipad", 76, 1, "icon-76.png"), ("ipad", 76, 2, "icon-76@2x.png"),
        ("ipad", 83.5, 2, "icon-83.5@2x.png"),
        ("ios-marketing", 1024, 1, "icon-1024.png"),
    ]
    images = []
    for idiom, pt, scale, fn in SPEC:
        px = int(round(pt * scale))
        master.resize((px, px), Image.LANCZOS).convert("RGB").save(
            os.path.join(out_dir, fn), optimize=True)
        images.append({"idiom": idiom, "size": f"{pt}x{pt}", "scale": f"{scale}x", "filename": fn})
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}},
              open(os.path.join(out_dir, "Contents.json"), "w"), indent=2)
    return len(images)


if __name__ == "__main__":
    meta = json.load(open(os.path.join(CAT, "manifest.json")))
    picks = meta[:8]
    made = []
    for i, m in enumerate(picks, 1):
        out = compose(m["file"])
        if out is None:
            print("跳过:", m["name"]); continue
        fn = os.path.join(COMPOSED, f"{i:02d}_{m['name']}.png")
        out.save(fn)
        made.append((i, m, fn))
        print(f"{i:>2} {m['name']:<20} 透明{m['transparent']:<6} 占比{m['cover']:<6} -> {os.path.basename(fn)}")

    # 对比图：4 列网格，带编号
    cols, cell, pad = 4, 300, 28
    rows = math.ceil(len(made) / cols)
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + pad + 34) + pad), (13, 17, 23))
    d = ImageDraw.Draw(sheet)
    for idx, (i, m, fn) in enumerate(made):
        r, c = divmod(idx, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + pad + 34)
        sheet.paste(Image.open(fn).resize((cell, cell), Image.LANCZOS), (x, y))
        d.text((x, y + cell + 8), f"#{i}  {m['name']}", fill=(230, 237, 243))
    sheet.save("/workspace/GitHubApp/cat-icons-候选.png")
    print("\n对比图 -> cat-icons-候选.png")
    print("母版素材:", [os.path.basename(f) for _, _, f in made])
