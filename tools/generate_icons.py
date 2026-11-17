#!/usr/bin/env python3
"""파스텔 타일 앱 아이콘을 만들어 web / android / ios 아이콘을 모두 교체한다.

    python3 tools/generate_icons.py      (Pillow 필요)
"""
import glob
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
S = 1024

# 좌우 대칭 하트 모양 패턴
PATTERN = [
    [0, 1, 0, 1, 0],
    [1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1],
    [0, 1, 1, 1, 0],
    [0, 0, 1, 0, 0],
]
PINK = (255, 194, 217)
PINK_DEEP = (247, 127, 171)
CREAM = (255, 248, 241)
LAVENDER = (201, 189, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(maskable: bool) -> Image.Image:
    img = Image.new("RGB", (S, S), CREAM)
    # 배경 그라데이션
    d = ImageDraw.Draw(img)
    for y in range(S):
        d.line([(0, y), (S, y)], fill=lerp((255, 246, 238), (241, 236, 255), y / S))
    margin = 210 if maskable else 120
    grid = S - margin * 2
    gap = grid * 0.05
    cell = (grid - gap * 4) / 5
    r = cell * 0.3
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    tiles = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    td = ImageDraw.Draw(tiles)
    for row in range(5):
        for col in range(5):
            x0 = margin + col * (cell + gap)
            y0 = margin + row * (cell + gap)
            box = [x0, y0, x0 + cell, y0 + cell]
            on = PATTERN[row][col] == 1
            sd.rounded_rectangle([box[0], box[1] + cell * 0.08, box[2], box[3] + cell * 0.08], r,
                                 fill=(*(PINK_DEEP if on else LAVENDER), 110))
            if on:
                # 대각선 그라데이션 캔디
                tile = Image.new("RGBA", (int(cell), int(cell)))
                tdd = ImageDraw.Draw(tile)
                for i in range(int(cell) * 2):
                    c = lerp(lerp(PINK, (255, 255, 255), 0.25), PINK_DEEP, i / (cell * 2))
                    tdd.line([(i, 0), (0, i)], fill=(*c, 255), width=2)
                m = Image.new("L", tile.size, 0)
                ImageDraw.Draw(m).rounded_rectangle([0, 0, cell - 1, cell - 1], r, fill=255)
                tiles.paste(tile, (int(x0), int(y0)), m)
            else:
                td.rounded_rectangle(box, r, fill=(255, 255, 255, 255), outline=(*LAVENDER, 255), width=int(cell * 0.05))
            # 광택
            td.rounded_rectangle([x0 + cell * 0.14, y0 + cell * 0.1, x0 + cell * 0.56, y0 + cell * 0.3], cell,
                                 fill=(255, 255, 255, 150 if on else 230))
    shadow = shadow.filter(ImageFilter.GaussianBlur(cell * 0.1))
    img.paste(shadow, (0, 0), shadow)
    img.paste(tiles, (0, 0), tiles)
    return img


def save(img: Image.Image, path: str, size: int) -> None:
    img.resize((size, size), Image.LANCZOS).save(path)
    print(f"  {os.path.relpath(path, ROOT)} {size}px")


def main() -> None:
    normal = render(False)
    maskable = render(True)
    for path in glob.glob(os.path.join(ROOT, "web", "icons", "*.png")) + [os.path.join(ROOT, "web", "favicon.png")]:
        size = Image.open(path).size[0]
        save(maskable if "maskable" in path else normal, path, size)
    for path in glob.glob(os.path.join(ROOT, "android", "app", "src", "main", "res", "mipmap-*", "ic_launcher.png")):
        save(normal, path, Image.open(path).size[0])
    for path in glob.glob(os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", "*.png")):
        save(normal, path, Image.open(path).size[0])


if __name__ == "__main__":
    main()
