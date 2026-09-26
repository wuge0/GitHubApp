#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""用 headless Chromium 抓 Pixabay 搜索页图片直链（Cloudflare 会拦 curl）"""
import json, sys, re
from playwright.sync_api import sync_playwright

DEFAULT = [
    ("cat-vector", "https://pixabay.com/vectors/search/cat/"),
    ("cat-head", "https://pixabay.com/vectors/search/cat%20head/"),
    ("cat-face", "https://pixabay.com/vectors/search/cat%20face/"),
    ("cat-illus", "https://pixabay.com/illustrations/search/cat%20face/"),
    ("kitten", "https://pixabay.com/vectors/search/kitten/"),
]

QUERIES = DEFAULT
if len(sys.argv) > 1:
    QUERIES = [(f"q{i}", u) for i, u in enumerate(sys.argv[1:])]

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
OUT_JSON = sys.argv[0].replace("pixabay_search.py", "pixabay_links.json")

rows = []
with sync_playwright() as p:
    browser = p.chromium.launch(
        headless=True,
        args=["--no-sandbox", "--disable-dev-shm-usage", "--disable-blink-features=AutomationControlled"],
        proxy={"server": "http://127.0.0.1:7890"},
    )
    pg = browser.new_page(viewport={"width": 1440, "height": 1000}, user_agent=UA)
    for name, url in QUERIES:
        try:
            pg.goto(url, wait_until="domcontentloaded", timeout=60000)
            pg.wait_for_timeout(5000)
            for _ in range(4):
                pg.mouse.wheel(0, 1400)
                pg.wait_for_timeout(1200)
            items = pg.evaluate("""() => {
                const out = [];
                document.querySelectorAll('img').forEach(im => {
                    const s = im.currentSrc || im.src || '';
                    if (!s.includes('cdn.pixabay.com')) return;
                    if (s.includes('/user/') || s.includes('avatar')) return;
                    const a = im.closest('a');
                    out.push({src: s, alt: im.alt || '', w: im.naturalWidth, h: im.naturalHeight,
                              page: a ? a.href : ''});
                });
                return out;
            }""")
            for it in items:
                it["query"] = name
            rows += items
            print(f"[{name}] {len(items)} 张", file=sys.stderr)
        except Exception as e:
            print(f"[{name}] 失败: {e}", file=sys.stderr)
    browser.close()

seen, out = set(), []
for r in rows:
    key = re.sub(r"_\d+\.(jpg|png|webp|svg)$", "", r["src"])
    if key in seen:
        continue
    seen.add(key)
    if r["w"] < 200:
        continue
    out.append(r)

json.dump(out, open(OUT_JSON, "w"), indent=2, ensure_ascii=False)
print(f"共 {len(out)} 条 -> {OUT_JSON}")
for r in out[:40]:
    print(f"  {r['w']}x{r['h']} {r['src']}")
