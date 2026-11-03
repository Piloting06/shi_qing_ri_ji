"""点景素材：从《芥子园画传》1679 年初版扫描（The Met 开放获取，CC0）裁出线稿。

每件：裁切 → 去纸色（按亮度阈值转 alpha，保留墨色深浅）→ 透明底 PNG（白色 RGB，靠 alpha 成形，
在 Flutter 里用 ColorFilter 染成墨色或夜色）。来源逐件记在 assets/motifs/SOURCES.md。

用法：python3 scripts/cut_motifs.py <扫描图目录>
  目录内需有 <objectID>_L.jpg（https://collectionapi.metmuseum.org/public/collection/v1/objects/<id> 的 primaryImage）
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'motifs'

# name: (objectID, 裁切框 (l, t, r, b)，原图像素)
MOTIFS = {
    'boat': ('63230', (790, 1815, 1165, 1975)),  # 孤舟：船头立一艄公
    'sail': ('63229', (2240, 1770, 2560, 2000)),  # 归帆
    'branch': ('63230', (415, 105, 735, 372)),  # 寒枝
}


def drop_specks(a: np.ndarray, min_px: int) -> np.ndarray:
    """去掉小于 min_px 的孤立墨点（扫描灰尘）：8 邻接连通域，纯 Python 栈式填充"""
    h, w = a.shape
    seen = np.zeros_like(a, bool)
    keep = np.zeros_like(a, bool)
    on = a > 0
    for y0, x0 in zip(*np.nonzero(on)):
        if seen[y0, x0]:
            continue
        stack, comp = [(y0, x0)], []
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and on[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        if len(comp) >= min_px:
            ys, xs = zip(*comp)
            keep[list(ys), list(xs)] = True
    return np.where(keep, a, 0)


def cut(src: Image.Image) -> Image.Image:
    g = np.asarray(src.convert('L'), np.float32)
    paper = np.percentile(g, 90)  # 纸色：取亮部
    ink = np.percentile(g, 1)
    a = ((paper - g) / max(paper - ink, 1)).clip(0, 1)
    a = np.where(a < 0.3, 0, a)  # 去纸纹与扫描底噪、水面淡晕
    a = drop_specks(a, min_px=60)
    a = (a ** 0.8 * 255).astype(np.uint8)
    rgba = np.zeros((*a.shape, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = a
    im = Image.fromarray(rgba)
    # 只留连通的主体：alpha 轻模糊后裁到非空外框
    box = im.getchannel('A').filter(ImageFilter.MaxFilter(3)).getbbox()
    return im.crop(box) if box else im


def main() -> None:
    src_dir = pathlib.Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (oid, box) in MOTIFS.items():
        im = Image.open(src_dir / f'{oid}_L.jpg').crop(box)
        out = cut(im)
        if out.width > 360:
            out = out.resize((360, round(out.height * 360 / out.width)), Image.LANCZOS)
        out.save(OUT / f'{name}.png', optimize=True)
        print(f'{name}.png ← {oid} {box}: {out.size}, {(OUT / f"{name}.png").stat().st_size // 1024} KB')


if __name__ == '__main__':
    main()
