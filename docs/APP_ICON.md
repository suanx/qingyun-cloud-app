# 轻云 App 启动图标

采用「方案 A · 渐变云」（见 `轻云-桌面图标方案`）：亮蓝 → 薄荷 125° 渐变底、
白色圆润云朵 + 上传箭头。色值来自 `DESIGN_SPEC.md`：

| 用途 | 色值 |
| --- | --- |
| 渐变起点 | `#2F6BFF` |
| 渐变中点 | `#4E8BFF` |
| 渐变终点 | `#37C9B4` |
| 云朵 / 箭头 | `#FFFFFF` |

## 设计源文件

`docs/assets/app-icon-master.png` —— **1024×1024、不透明、内容铺满画布**。
这是唯一母版：无外部背景、无投影、无圆角、无文字，系统遮罩负责切圆角。
重出任何尺寸都从它缩放，不要再回到带浅灰底和投影的提案展示图。

## 落地结构

### iOS
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024.png` —— 母版直接落盘
- `Contents.json` 保持 `universal / ios / 1024x1024`，Xcode 自动派生各尺寸
- 注意：iOS 图标**必须不透明**，不要给母版加 alpha 通道

### Android
| 资源 | 说明 |
| --- | --- |
| `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` | 48/72/96/144/192 legacy 图标，自带 squircle 圆角 + 透明四角 |
| `mipmap-anydpi-v26/ic_launcher.xml` | API 26+ 自适应图标，引用下面两层 |
| `drawable/ic_launcher_background_gradient.xml` | 背景层：`shape` 渐变，angle 315（左上→右下，等价 CSS 125deg） |
| `drawable/ic_launcher_foreground.xml` | 前景层：**矢量**云朵 + 箭头，108dp 画布、图形占中心 60dp（66dp 安全区内） |
| `values/colors.xml` 的 `ic_launcher_background` | 兼容项，已同步为主蓝；adaptive 不再引用 |

已删除 `mipmap/ic_launcher.xml`（旧的钢青蓝 `#4A7386` + 黄色 vector），
避免无密度限定的默认资源在某些设备上串出旧图标。API < 26 由各密度 PNG 覆盖。

前景矢量是从方案 A 原图的云朵/箭头轮廓提取并简化得到（73 个点），
因此自适应图标与 iOS/legacy 位图的形状完全一致，且任意密度都清晰。

## 更换流程

1. 替换 `docs/assets/app-icon-master.png`
2. 重新生成 5 个密度 legacy PNG（加 squircle 圆角 alpha）
3. iOS 直接替换 `icon-1024.png`
4. 若云形改了，重新提取轮廓更新 `drawable/ic_launcher_foreground.xml` 的 `pathData`
5. 渐变色改了，更新 `ic_launcher_background_gradient.xml` 的三个色值

## 未覆盖

- Windows `.ico` / macOS `.icns`：本仓库是 Flutter 双端工程（android / ios），无桌面端目录
- Android 启动屏 `drawable/launch_background.xml` 仍是纯白，未随图标改动
