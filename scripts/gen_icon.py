"""App 图标：宣纸底上一枚白文朱印「晴」（P9 笺谱）。

产出：
- 自适应图标（Android 8+）：mipmap-*/ic_launcher_foreground.png（108dp 画布，印居中占安全区）
  + mipmap-anydpi-v26/ic_launcher.xml（背景色 @color/ic_launcher_background 宣纸）
- 旧式图标：mipmap-*/ic_launcher.png（宣纸方底 + 印）

印：思源宋 600 子集刻字（白文：红底留白），四边逐段抖动、崩口，按纸纹（assets/textures/paper.png）做印泥斑驳。
用法：python3 scripts/gen_icon.py
"""
import math
import pathlib
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
FONT = ROOT / 'assets' / 'fonts' / 'NotoSerifSC-600.otf'
TEX = ROOT / 'assets' / 'textures' / 'paper.png'
PAPER = (237, 232, 220)
SEAL = (174, 54, 36)
DENS = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def seal(size: int) -> Image.Image:
    """透明底上的一枚印，边长 size"""
    rng = random.Random(7)
    s = size
    img = Image.new('L', (s, s), 0)
    d = ImageDraw.Draw(img)
    inset, j = s * 0.04, s * 0.012
    pts = []
    for side in range(4):
        for i in range(8):
            t = i / 8
            jit = (rng.random() - 0.5) * 2 * j
            x, y = [
                (inset + t * (s - 2 * inset), inset + jit),
                (s - inset + jit, inset + t * (s - 2 * inset)),
                (s - inset - t * (s - 2 * inset), s - inset + jit),
                (inset + jit, s - inset - t * (s - 2 * inset)),
            ][side]
            pts.append((x, y))
    d.polygon(pts, fill=255)
    # 白文：刻掉「晴」
    font = ImageFont.truetype(str(FONT), int(s * 0.66))
    glyph = Image.new('L', (s, s), 0)
    gd = ImageDraw.Draw(glyph)
    box = gd.textbbox((0, 0), '晴', font=font)
    gw, gh = box[2] - box[0], box[3] - box[1]
    gd.text(((s - gw) / 2 - box[0], (s - gh) / 2 - box[1]), '晴', font=font, fill=255)
    glyph = glyph.filter(ImageFilter.MaxFilter(3 if s < 300 else 5))  # 刀口略粗
    img = ImageChops.subtract(img, glyph)
    # 崩口
    for _ in range(4):
        side = rng.randrange(4)
        t = inset + rng.random() * (s - 2 * inset)
        cx, cy = [(t, inset), (s - inset, t), (t, s - inset), (inset, t)][side]
        rx, ry = s * (0.006 + rng.random() * 0.012), s * (0.004 + rng.random() * 0.008)
        if side in (1, 3):
            rx, ry = ry, rx
        ImageDraw.Draw(img).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=0)
    # 印泥斑驳：纸纹 alpha 侵蚀
    tex = Image.open(TEX).getchannel('A').resize((s, s), Image.BILINEAR)
    tex = tex.point(lambda a: int(a * 0.75))
    img = ImageChops.subtract(img, tex)
    out = Image.new('RGBA', (s, s), SEAL + (0,))
    out.putalpha(img)
    return out.rotate(-3, resample=Image.BICUBIC, expand=False)


def paper(size: int) -> Image.Image:
    bg = Image.new('RGBA', (size, size), PAPER + (255,))
    tex = Image.open(TEX).resize((size, size), Image.BILINEAR)
    fiber = Image.new('RGBA', (size, size), (74, 59, 38, 0))
    fiber.putalpha(tex.getchannel('A').point(lambda a: int(a * 0.16)))
    bg.alpha_composite(fiber)
    return bg


def main() -> None:
    big = seal(1024)
    for name, k in DENS.items():
        folder = RES / f'mipmap-{name}'
        folder.mkdir(exist_ok=True)
        # 旧式：48dp 方底，印占 62%
        n = round(48 * k)
        legacy = paper(n)
        sz = round(n * 0.62)
        legacy.alpha_composite(big.resize((sz, sz), Image.LANCZOS), ((n - sz) // 2, (n - sz) // 2))
        legacy.convert('RGB').save(folder / 'ic_launcher.png', optimize=True)
        # 自适应前景：108dp，印占 50%（落在 66dp 安全区内）
        f = round(108 * k)
        fg = Image.new('RGBA', (f, f), (0, 0, 0, 0))
        sz = round(f * 0.5)
        fg.alpha_composite(big.resize((sz, sz), Image.LANCZOS), ((f - sz) // 2, (f - sz) // 2))
        fg.save(folder / 'ic_launcher_foreground.png', optimize=True)
    any_dir = RES / 'mipmap-anydpi-v26'
    any_dir.mkdir(exist_ok=True)
    (any_dir / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n',
        'utf-8',
    )
    big_preview = paper(512)
    big_preview.alpha_composite(big.resize((320, 320), Image.LANCZOS), (96, 96))
    big_preview.save(ROOT / 'build' / 'icon_preview.png')
    print('ok')


if __name__ == '__main__':
    main()
