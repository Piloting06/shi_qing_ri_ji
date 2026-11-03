# 点景素材来源

全部取自《芥子园画传》（王概等编绘）1679 年初版木刻页，The Metropolitan Museum of Art 开放获取（Open Access，CC0，可商用）。
处理脚本：`scripts/cut_motifs.py`（裁切 → 去纸色转 alpha → 去扫描噪点 → 透明底白色线稿，运行时按天色染色）。

| 文件 | 内容 | The Met 藏品 | 裁切框（原图像素） |
|---|---|---|---|
| `boat.png` | 孤舟，船头立一艄公 | [63230](https://www.metmuseum.org/art/collection/search/63230) | 790, 1815, 1165, 1975 |
| `sail.png` | 归帆 | [63229](https://www.metmuseum.org/art/collection/search/63229) | 2240, 1770, 2560, 2000 |
| `branch.png` | 寒枝 | [63230](https://www.metmuseum.org/art/collection/search/63230) | 415, 105, 735, 372 |

原图通过 `https://collectionapi.metmuseum.org/public/collection/v1/objects/<id>` 的 `primaryImage` 下载，`isPublicDomain: true`（2026-11-04 核对）。
