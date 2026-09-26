#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""下载 Pixabay 素材（自动尝试 _1280 / _1920 高分辨率版本）"""
import json, os, re, urllib.request, urllib.error

LINKS = "/workspace/GitHubApp/pixabay_links.json"
OUT = "/workspace/GitHubApp/materials"
os.makedirs(OUT, exist_ok=True)

# 优先挑选：正方形/图标感/编程代码主题
PREFER = [
    "code-1076536", "code-8779051", "code-7146975", "code-1839406",
    "coding-1841550", "coding-924920", "coding-1931667",
    "programming-1836330", "programming-1873854", "programming-2115930",
    "binary-code-475664", "icons-7309514", "matrix-356024",
    "software-developer-6521720", "technology-1283624", "visual-basic-906838",
    "digital-484402", "cloud-4828390",
]
items = json.load(open(LINKS))
picked = []
for pref in PREFER:
    for it in items:
        if pref in it["src"]:
            picked.append(it)
            break

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0 Safari/537.36"
opener = urllib.request.build_opener(urllib.request.ProxyHandler({"https": "http://127.0.0.1:7890",
                                                                  "http": "http://127.0.0.1:7890"}))
opener.addheaders = [("User-Agent", UA), ("Referer", "https://pixabay.com/")]

meta = []
for it in picked:
    base = it["src"]
    slug = re.search(r"/([^/]+)_\d+\.(jpg|png|webp)$", base)
    name = slug.group(1) if slug else os.path.basename(base)
    ext = slug.group(2) if slug else "jpg"
    got = None
    for size in ("_1280", "_960", "_640"):
        url = re.sub(r"_\d+\.(jpg|png|webp)$", size + "." + ext, base)
        if url == base and size != "_640":
            continue
        try:
            with opener.open(url, timeout=30) as r:
                data = r.read()
            if len(data) > 3000:
                got = (url, data)
                break
        except urllib.error.HTTPError:
            continue
        except Exception:
            continue
    if not got:
        print("失败:", base)
        continue
    url, data = got
    path = os.path.join(OUT, f"{name}_{len(data)}.{ext}") if False else os.path.join(OUT, f"{name}.{ext}")
    open(path, "wb").write(data)
    meta.append({"name": name, "file": path, "url": url, "bytes": len(data)})
    print(f"OK {name}.{ext}  {len(data)//1024}KB  <- {url}")

json.dump(meta, open(os.path.join(OUT, "manifest.json"), "w"), indent=2, ensure_ascii=False)
print("下载完成:", len(meta), "张 ->", OUT)
