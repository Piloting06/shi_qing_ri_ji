"""宋体子集生成：Noto Serif SC（OFL）→ assets/fonts/NotoSerifSC-{500,600}.otf

字符集 = GB2312 一级常用字（3755）+ lib/ 源码里出现的全部汉字 + 中文标点 + ASCII。
新增界面文案后重跑即可；生成后自检汉字数，防止「子集里一个汉字都没有」的静默失败。

用法：python3 scripts/subset_serif.py <源字体目录>
  源目录需含 NotoSerifSC-Medium.otf / NotoSerifSC-SemiBold.otf
  （https://github.com/notofonts/noto-cjk/tree/main/Serif/SubsetOTF/SC）
"""
import pathlib
import re
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'fonts'
WEIGHTS = {'Medium': '500', 'SemiBold': '600'}
MIN_CJK = 3700


def charset() -> str:
    chars = set()
    for hi in range(0xB0, 0xD8):  # GB2312 一级字区
        for lo in range(0xA1, 0xFF):
            try:
                chars.add(bytes([hi, lo]).decode('gb2312'))
            except UnicodeDecodeError:
                pass
    for f in (ROOT / 'lib').rglob('*.dart'):
        chars.update(re.findall(r'[　-〿一-鿿＀-￯]', f.read_text('utf-8')))
    chars.update(chr(c) for c in range(0x20, 0x7F))
    chars.update('·—…“”‘’、。，：；！？「」『』《》（）【】〔〕°℃‹›←→↑↓×～')
    # 汉字纪年的〇与竖排标点（卡片竖写用；字形取自原字体）
    chars.update('〇︙︱﹁﹂﹃﹄︵︶︹︺︽︾﹇﹈︐︑︒')
    return ''.join(sorted(chars))


def main() -> None:
    src = pathlib.Path(sys.argv[1])
    text = charset()
    for name, weight in WEIGHTS.items():
        out = OUT / f'NotoSerifSC-{weight}.otf'
        opts = subset.Options()
        opts.layout_features = ['kern', 'liga', 'vert', 'locl', 'palt']
        opts.name_IDs = ['*']
        font = subset.load_font(str(src / f'NotoSerifSC-{name}.otf'), opts)
        sub = subset.Subsetter(opts)
        sub.populate(text=text)
        sub.subset(font)
        subset.save_font(font, str(out), opts)
        cmap = TTFont(str(out)).getBestCmap()
        cjk = sum(1 for c in cmap if 0x4E00 <= c <= 0x9FFF)
        if cjk < MIN_CJK:
            sys.exit(f'{out.name}: 只有 {cjk} 个汉字，子集失败')
        print(f'{out.name}: {cjk} 个汉字, {out.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main()
