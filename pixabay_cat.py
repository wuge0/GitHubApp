#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""下载 Pixabay 猫/猫头候选，并按"适合作图标"打分排序"""
import json, os, re, urllib.request, urllib.error
from collections import Counter
import numpy as np
from PIL import Image

LINKS = "/workspace/GitHubApp/pixabay_links.json"
OUT = "/workspace/GitHubApp/materials/cat"
os.makedirs(OUT, exist_ok=True)

items = json.load(open(LINKS))

# 只看猫科/卡通猫相关的，排除虎/狮/豹等野兽（除非名字就是 cat）
BAD = ("tiger", "lion", "leopard", "panther", "cheetah", "bobcat", "wildcat",
       "snowman", "bear", "crossbones", "ai-generated", "big-")
GOOD = ("cat", "kitten", "cartoon", "logo", "pet", "feline", "animal")

cands = []
for it in items:
    m = re.search(r"/([^/]+)_\d+\.(png|jpg|webp)$", it["src"])
    if not m:
        continue
    name, ext = m.group(1), m.group(2)
    if any(b in name for b in BAD):
        continue
    if not any(g in name for g in GOOD):
        continue
    if it["w"] < 480:
        continue
    cands.append({**it, "name": name, "ext": ext})

# 正方形 & PNG & 大尺寸优先
def pre(it):
    ar = min(it["w"], it["h"]) / max(it["w"], it["h"])
    return (it["ext"] == "png", ar, it["w"] * it["h"])
cands.sort(key=pre, reverse=True)
cands = cands[:24]
print(f"候选 {len(cands)} 张")

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0 Safari/537.36"
opener = urllib.request.build_opener(urllib.request.ProxyHandler({"https": "http://127.0.0.1:7890",
                                                                 "http": "http://127.0.0.1:7890"}))
opener.addheaders = [("User-Agent", UA), ("Referer", "https://pixabay.com/")]


def fetch(base, ext):
    for size in ("_1280", "_960", "_640"):
        url = re.sub(r"_\d+\.(png|jpg|webp)$", size + "." + ext, base)
        try:
            with opener.open(url, timeout=30) as r:
                d = r.read()
            if len(d) > 3000:
                return url, d
        except Exception:
            continue
    return None, None


meta = []
for it in cands:
    url, data = fetch(it["src"], it["ext"])
    if not url:
        continue
    path = os.path.join(OUT, f"{it['name']}.{it['ext']}")
    open(path, "wb").write(data)

    im = Image.open(path)
    im.load()
    rgba = im.convert("RGBA")
    a = np.array(rgba)
    alpha = a[..., 3]
    transparent = float((alpha < 250).mean())

    # 主体包围盒（用 alpha 或 与角落色的差异）
    if transparent > 0.05:
        mask = alpha > 16
    else:
        bg = np.array([a[2, 2, :3], a[2, -3, :3], a[-3, 2, :3], a[-3, -3, :3]]).mean(axis=0)
        diff = np.abs(a[..., :3].astype(int) - bg).sum(axis=2)
        mask = diff > 60
    ys, xs = np.where(mask)
    if len(xs) == 0:
        cover, ar_sub = 0, 0
    else:
        bw, bh = xs.max() - xs.min(), ys.max() - ys.min()
        cover = float(mask.mean())
        ar_sub = min(bw, bh) / max(bw, bh)

    # 扁平度：颜色数量（量化后）
    q = (a[..., :3] // 32).reshape(-1, 3)
    colors = len(Counter(map(tuple, q[mask.reshape(-1)] if mask.any() else q)))

    w, h = im.size
    ar = min(w, h) / max(w, h)
    # 打分：透明背景 + 主体饱满 + 近正方 + 配色扁平
    score = (transparent * 2.0 + min(cover * 3, 1.5) + ar * 1.0
             + ar_sub * 0.5 + (1.0 if colors <= 60 else 0.3))
    meta.append({"name": it["name"], "file": path, "url": url, "size": [w, h],
                 "transparent": round(transparent, 3), "cover": round(cover, 3),
                 "ar": round(ar, 3), "ar_subject": round(ar_sub, 3), "colors": colors,
                 "score": round(score, 3)})

meta.sort(key=lambda m: -m["score"])
json.dump(meta, open(os.path.join(OUT, "manifest.json"), "w"), indent=2, ensure_ascii=False)

print(f"\n{'#':>2} {'名字':<24} {'尺寸':<11} {'透明':>6} {'占比':>6} {'配色数':>6} {'分数':>6}")
for i, m in enumerate(meta, 1):
    print(f"{i:>2} {m['name']:<24} {str(m['size'][0])+'x'+str(m['size'][1]):<11} "
          f"{m['transparent']:>6} {m['cover']:>6} {m['colors']:>6} {m['score']:>6}")
