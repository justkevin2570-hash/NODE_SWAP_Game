"""플레이 스토어 그래픽 이미지(1024x500)를 한국어·영어로 만든다.

    python3 tools/generate_feature_graphic.py   (결과: release/store_graphics/)
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
FONT = ROOT + '/tools/fonts/Jua-Regular.full.ttf'
K = 2  # 2배로 그린 뒤 줄인다
W, H = 1024 * K, 500 * K

INK = (75, 66, 99); SOFT = (139, 131, 163); WHITE = (255, 255, 255)
PINK = ((255, 194, 217), (247, 127, 171)); SKY = ((189, 224, 255), (109, 181, 242))
MINT = ((174, 235, 216), (95, 204, 171)); LAV = ((201, 189, 255), (154, 135, 242))
PEACH = ((255, 205, 181), (255, 158, 125)); BUTTER = ((255, 235, 166), (247, 201, 72))

def font(px): return ImageFont.truetype(FONT, px * K)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def background():
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        d.line([(0, y), (W, y)], fill=lerp((255, 248, 241), (241, 238, 255), y / H))
    blobs = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blobs)
    for x, y, r, c in [(120, 80, 260, (255, 194, 217, 120)), (560, 470, 260, (174, 235, 216, 110)),
                       (980, 60, 240, (189, 224, 255, 120)), (880, 470, 220, (255, 235, 166, 110)),
                       (380, 260, 200, (201, 189, 255, 70))]:
        bd.ellipse(((x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K), fill=c)
    blobs = blobs.filter(ImageFilter.GaussianBlur(80 * K))
    img.paste(blobs, (0, 0), blobs)
    return img

def shadow_layer(size, box, radius, color, blur, offset=(0, 0), alpha=90):
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        (box[0] + offset[0], box[1] + offset[1], box[2] + offset[0], box[3] + offset[1]), radius, fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(blur))

def tile(img, cx, cy, size, colors, ch=None, tilt=0, fsize=None, filled=True):
    """앱의 타일 모양: 그라데이션 + 흰 테두리 + 위쪽 하이라이트 + 그림자."""
    light, deep = colors
    s = int(size)
    pad = int(s * 0.5)
    t = Image.new('RGBA', (s + pad * 2, s + pad * 2), (0, 0, 0, 0))
    box = (pad, pad, pad + s, pad + s)
    r = int(s * 0.3)
    t.alpha_composite(shadow_layer(t.size, box, r, deep, s * 0.08, (0, int(s * 0.08)), 110))
    fill = Image.new('RGBA', (s, s))
    fd = ImageDraw.Draw(fill)
    top = lerp(light, WHITE, 0.35) if filled else (255, 255, 255)
    bot = light if filled else (246, 243, 255)
    for i in range(s):
        fd.line([(0, i), (s, i)], fill=lerp(top, bot, i / s) + (255,))
    mask = Image.new('L', (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), r, fill=255)
    t.paste(fill, (pad, pad), mask)
    d = ImageDraw.Draw(t)
    d.rounded_rectangle(box, r, outline=WHITE if filled else (226, 219, 247), width=max(2, int(s * 0.05)))
    if filled:
        d.rounded_rectangle((pad + s * 0.16, pad + s * 0.12, pad + s * 0.58, pad + s * 0.26), int(s * 0.07), fill=(255, 255, 255, 150))
    if ch:
        f = font(fsize or int(s / K * 0.6))
        bb = d.textbbox((0, 0), ch, font=f)
        d.text((pad + s / 2 - (bb[0] + bb[2]) / 2, pad + s / 2 - (bb[1] + bb[3]) / 2), ch, font=f, fill=INK)
    if tilt:
        t = t.rotate(tilt, resample=Image.BICUBIC)
    img.alpha_composite(t, (int(cx - t.width / 2), int(cy - t.height / 2)))

def logo(img, cx, top):
    sym = 'SYMMETRY'
    sc = [PINK, SKY, MINT, LAV]
    small = 50 * K
    step = small * 1.14
    x0 = cx - step * (len(sym) - 1) / 2
    for i, ch in enumerate(sym):
        tile(img, x0 + i * step, top + small / 2, small, sc[min(i, len(sym) - 1 - i)], ch)
    rush = 'RUSH'
    big = 82 * K
    step = big * 1.14
    x0 = cx - step * (len(rush) - 1) / 2
    for i, ch in enumerate(rush):
        tile(img, x0 + i * step, top + small + 20 * K + big / 2, big, [PINK, PEACH, BUTTER, PEACH][i], ch,
             tilt=4 if i % 2 == 0 else -4)
    return top + small + 20 * K + big

def board(img, cx, cy, size):
    """대칭(좌우)인 5x5 보드 + 점선 축."""
    pattern = ['10101', '11011', '01110', '10001', '01110']
    panel = int(size)
    r = 34 * K
    x0, y0 = int(cx - panel / 2), int(cy - panel / 2)
    img.alpha_composite(shadow_layer(img.size, (x0, y0, x0 + panel, y0 + panel), r, (247, 127, 171), 30 * K, (0, 14 * K), 70))
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle((x0, y0, x0 + panel, y0 + panel), r, fill=(255, 255, 255, 150), outline=WHITE, width=3 * K)
    img.alpha_composite(layer)
    padd, gap = 16 * K, 9 * K
    cell = (panel - padd * 2 - gap * 4) / 5
    d = ImageDraw.Draw(img)
    # 축 띠
    ax = cx
    band = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(band).rounded_rectangle((ax - cell / 2 - 4 * K, y0 + 8 * K, ax + cell / 2 + 4 * K, y0 + panel - 8 * K), 22 * K, fill=(247, 127, 171, 30))
    img.alpha_composite(band)
    for rr in range(5):
        for c in range(5):
            tx = x0 + padd + c * (cell + gap) + cell / 2
            ty = y0 + padd + rr * (cell + gap) + cell / 2
            tile(img, tx, ty, cell, PINK, filled=pattern[rr][c] == '1')
    d = ImageDraw.Draw(img)
    dash, g = 12 * K, 10 * K
    y = y0 - 10 * K
    while y < y0 + panel + 10 * K:
        d.line([(ax, y), (ax, min(y + dash, y0 + panel + 10 * K))], fill=(247, 127, 171), width=4 * K)
        y += dash + g

def chip(img, cx, cy, text, colors, f):
    light, deep = colors
    d = ImageDraw.Draw(img)
    bb = d.textbbox((0, 0), text, font=f)
    w, h = bb[2] - bb[0] + 44 * K, bb[3] - bb[1] + 26 * K
    box = (int(cx - w / 2), int(cy - h / 2), int(cx + w / 2), int(cy + h / 2))
    img.alpha_composite(shadow_layer(img.size, box, h // 2, deep, 8 * K, (0, 4 * K), 80))
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, h // 2, fill=lerp(light, WHITE, 0.2) + (255,), outline=WHITE, width=3 * K)
    img.alpha_composite(layer)
    d = ImageDraw.Draw(img)
    d.text((cx - (bb[0] + bb[2]) / 2, cy - (bb[1] + bb[3]) / 2), text, font=f, fill=INK)

def make(lang):
    img = background().convert('RGBA')
    left_cx = 330 * K
    bottom = logo(img, left_cx, 72 * K)
    d = ImageDraw.Draw(img)
    tag = 'Swap, rotate, make it symmetric!' if lang == 'en' else '밀고, 돌리고, 대칭을 완성하세요!'
    f = font(30)
    bb = d.textbbox((0, 0), tag, font=f)
    d.text((left_cx - (bb[0] + bb[2]) / 2, bottom + 34 * K), tag, font=f, fill=SOFT)
    chips = (['60s Rush', '300 Stages', 'Daily Puzzle'] if lang == 'en' else ['60초 러시', '300탄 스테이지', '오늘의 퍼즐'])
    fc = font(22)
    widths = [d.textbbox((0, 0), c, font=fc)[2] + 44 * K for c in chips]
    gapc = 16 * K
    x = left_cx - (sum(widths) + gapc * (len(chips) - 1)) / 2
    for c, w, col in zip(chips, widths, [PINK, SKY, BUTTER]):
        chip(img, x + w / 2, bottom + 112 * K, c, col, fc)
        x += w + gapc
    board(img, 812 * K, 250 * K, 340 * K)
    out = img.convert('RGB').resize((1024, 500), Image.LANCZOS)
    os.makedirs(f'{ROOT}/release/store_graphics', exist_ok=True)
    path = f'{ROOT}/release/store_graphics/feature_graphic_{lang}.png'
    out.save(path)
    print(path, out.size)

for lang in ['en', 'ko']:
    make(lang)
