#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 draw_octo 生成的猫头母版写成 AppIcon.appiconset（18 个尺寸 + Contents.json）"""
import os, sys, json
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw_octo import render_octo

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "GitHubApp", "Assets.xcassets", "AppIcon.appiconset")

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

if __name__ == "__main__":
    master = render_octo((13, 17, 23), (240, 243, 246))   # 黑底白猫·GitHub 风
    os.makedirs(OUT, exist_ok=True)
    images = []
    for idiom, pt, scale, fn in SPEC:
        px = int(round(pt * scale))
        master.resize((px, px), Image.LANCZOS).convert("RGB").save(
            os.path.join(OUT, fn), optimize=True)
        images.append({"idiom": idiom, "size": f"{pt}x{pt}",
                       "scale": f"{scale}x", "filename": fn})
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}},
              open(os.path.join(OUT, "Contents.json"), "w"), indent=2)
    print(f"{len(images)} 个图标 -> {OUT}")
