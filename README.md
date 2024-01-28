<p align="center">

<img width="128" alt="icon-256" src="https://user-images.githubusercontent.com/5410705/167120035-b6993feb-ef8b-418b-9025-041571fa955b.png">

</p>

<h1 align="center">JSTColorPicker</h1>

<p align="center"><i>Lessica &lt;82flex@gmail.com&gt;</i></p>

JSTColorPicker 是一款专为 macOS 设计并优化的多功能位图取色和标注工具，能够为 PNG 或 JPEG 位图选择颜色和坐标，或添加矩形的矢量标注，支持自定义格式灵活导出。

![2880x1800bb](https://user-images.githubusercontent.com/5410705/166115782-64128c68-3226-4e5e-a0e0-786091411b81.png)

## 主要功能

- 从 PNG/JPG 屏幕截图文稿中标注坐标、颜色和矩形区域。
- 从 PNG/JPG 的 EXIF 字典的 `UserComment` 字段中读/写标注器数据。
- 在不同文稿间套用自定义模板（如 PASCAL VOC），以复制或导出标注器数据。
- 直接从 iOS/Android 设备上获取屏幕截图

## 软件特色

- 完整支持 Magic Trackpad 妙控板、Magic Mouse 妙控鼠标和一般 PC 鼠标，为标注效率赋能。
- 高精度：最高可放大至 256 倍，支持像素级别的网格状标注精度。
- 标签库：支持自定义标签及标签色彩，支持通过鼠标拖拽进行快速打标。
- 标注迁移：在相同尺寸的文稿间通过复制、粘贴，迁移标注器数据。
- 智能裁切：使用 Canny 边缘检测算法快速裁切矩形选区。
- 差异分析：分析并显示不同图像之间的差异。
- 侧边栏：多颜色检视器、缩略图预览、多模版快速预览。
- 快捷键：完整的自定义快捷键与指令面板支持。
- 打印：为位图添加美观的矢量标注，随后输出到 PDF 或者打印。
- 基于 Lua 的自定义动态导出模版
- Python SDK

## 适用场景

- 为收据、小票、合同等格式文本标注打印区域。
- 按键精灵、触摸精灵等自动化测试工具的图像采样与标记。
- 计算机视觉、人工智能等需要大量图像打标训练的领域。
- 只需携带一台 Mac，无需再携带 PC 和使用 Windows。

## 版权声明

JSTColorPicker 由 [@Lessica](https://github.com/Lessica) 开发，是 [GNU General Public License](LICENSE) 授权下的 [自由软件](https://www.gnu.org/philosophy/free-sw.html)。
