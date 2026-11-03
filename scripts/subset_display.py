"""展示字体子集：朱雀仿宋（OFL-1.1，TrionesType/zhuque）→ assets/fonts/ZhuqueFangsong-sub.ttf

字符集与 subset_serif.py 相同（GB2312 一级字 + lib/ 全部汉字 + 标点），新增文案后两份子集一起重跑。
生成后自检汉字数；授权文本随字体放在 assets/fonts/ZhuqueFangsong-OFL.txt。

用法：python3 scripts/subset_display.py <源 TTF> [输出路径]
  源字体：https://github.com/TrionesType/zhuque/releases （ZhuqueFangsong-Regular.ttf）
  第二个参数可把别的候选字体子集到别处做对比（不进仓库）
"""
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from subset_serif import MIN_CJK, ROOT, charset  # noqa: E402


def main() -> None:
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / 'assets' / 'fonts' / 'ZhuqueFangsong-sub.ttf'
    opts = subset.Options()
    opts.layout_features = ['kern', 'liga', 'vert', 'locl', 'palt']
    opts.name_IDs = ['*']
    font = subset.load_font(str(src), opts)
    sub = subset.Subsetter(opts)
    sub.populate(text=charset())
    sub.subset(font)
    subset.save_font(font, str(out), opts)
    cmap = TTFont(str(out)).getBestCmap()
    cjk = sum(1 for c in cmap if 0x4E00 <= c <= 0x9FFF)
    if cjk < MIN_CJK:
        sys.exit(f'{out.name}: 只有 {cjk} 个汉字，子集失败')
    print(f'{out.name}: {cjk} 个汉字, {out.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main()
