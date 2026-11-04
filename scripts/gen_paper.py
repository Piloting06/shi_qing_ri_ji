"""宣纸纹理生成：assets/textures/paper.png（512×512，可无缝平铺，RGBA）

RGB 恒为白，alpha 为纹理强度（0–255）：
- 细颗粒：逐像素噪声（纸面的「粉」）
- 云斑：低频噪声（纸浆厚薄不匀）
- 纤维：随机弯曲短线（宣纸里的檀皮纤维）
- 帘纹：极淡的横向条纹（抄纸竹帘留下的）

用法：在 Flutter 里以 ColorFilter(srcIn) 染成墨色/月白后叠在纸色上，或以 dstOut 侵蚀版画边缘。
全部用 FFT 周期卷积与取模绘制，左右上下首尾相接。
用法：python3 scripts/gen_paper.py
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'textures' / 'paper.png'
N = 512
rng = np.random.default_rng(20261104)


def periodic_blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """FFT 高斯模糊（天然周期，平铺无缝）"""
    fy = np.fft.fftfreq(a.shape[0])[:, None]
    fx = np.fft.fftfreq(a.shape[1])[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def norm(a: np.ndarray) -> np.ndarray:
    a = a - a.min()
    return a / (a.max() + 1e-9)


grain = norm(rng.random((N, N)))
mottle = norm(periodic_blur(rng.standard_normal((N, N)), 22))
mottle_fine = norm(periodic_blur(rng.standard_normal((N, N)), 5))

fiber = np.zeros((N, N))
for _ in range(900):
    x, y = rng.random(2) * N
    ang = rng.random() * np.pi
    length = 6 + rng.random() * 28
    curve = (rng.random() - 0.5) * 0.08
    strength = 0.35 + rng.random() * 0.65
    for s in np.arange(0, length, 0.5):
        a = ang + curve * s
        px = int(x + np.cos(a) * s) % N
        py = int(y + np.sin(a) * s) % N
        fiber[py, px] = max(fiber[py, px], strength)
fiber = norm(periodic_blur(fiber, 0.6))

yy = np.arange(N)[:, None]
laid = (np.sin(yy / N * 2 * np.pi * 64) * 0.5 + 0.5) ** 6  # 64 道帘纹，正好整除周期
laid = np.broadcast_to(laid, (N, N)) * (0.6 + 0.4 * mottle_fine)

alpha = (
    grain * 0.30
    + (mottle - 0.5).clip(0) * 0.55
    + mottle_fine * 0.12
    + fiber * 0.85
    + laid * 0.10
)
alpha = norm(alpha) ** 1.6  # 压暗大部分、只留细节
a8 = (alpha * 255).clip(0, 255).astype(np.uint8)

rgba = np.zeros((N, N, 4), np.uint8)
rgba[..., :3] = 255
rgba[..., 3] = a8
OUT.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(rgba).save(OUT, optimize=True)
print(f'{OUT.relative_to(ROOT)}: {OUT.stat().st_size // 1024} KB, alpha mean {a8.mean():.1f}')
