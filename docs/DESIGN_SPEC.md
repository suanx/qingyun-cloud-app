# 轻云设计规范（DESIGN SPEC）

本规范提炼自《轻云 · 移动端云盘 UI 设计方案》与 `packages/qingyun_ui_kit` 组件骨架，是全部 UI 代码的实现依据。

## 1. 设计基调

- 关键词：纯白 · 钢青蓝灰 · 彩色图标 · 磨砂玻璃
- **所有页面背景纯白**，不使用渐变与装饰底纹
- 主色钢青蓝灰，近黑文字 + 冷灰次级文字
- 功能图标统一为「彩色圆角浅底 + 同族深色描边图形」（`QyTintedIcon`）
- **全局磨砂玻璃质感**：`QyFrost`（BackdropFilter 高斯模糊 + 半透明面 + 细描边），应用于卡片、列表项、应用栏、底部导航、分类胶囊、Toast 等全部容器

## 2. 色彩（QyColors）

| Token | 值 | 用途 |
| --- | --- | --- |
| `primary` | `#4A7386` | 主色（按钮、选中态、进度） |
| `primaryDeep` | `#39596A` | 主色加深（强调） |
| `primaryLight` | `#E3EDF2` | 浅主色（次级按钮、彩色图标底） |
| `canvas` | `#FFFFFF` | 全局背景（纯白） |
| `surface` | `#FFFFFF` | 卡片/导航面 |
| `surfaceSoft` | `#F4F7F9` | 浅灰蓝卡片底（强调卡片、输入框填充） |
| `sky` / `mint` / `violet` / `gold` / `coral` / `leaf` | `#4E8FD9` / `#2FB5A3` / `#8B7CD8` / `#D9A441` / `#E96A5B` / `#43AE7C` | 彩色图标色族 |
| `ink` | `#20262B` | 主文字 |
| `sub` | `#8B959E` | 次级文字 |
| `muted` | `#B7BFC6` | 弱化文字/图标 |
| `border` / `divider` | `#E9EDF0` / `#F1F4F6` | 描边/分割 |
| `success` / `error` | `#43AE7C` / `#E96A5B` | 成功/失败 |
| `softShadow` | `#14809AAB`（8% 冷灰蓝） | 统一阴影色 |

## 3. 尺寸与形状（QyTokens）

| Token | 值 |
| --- | --- |
| 按钮高度 | **52** |
| 卡片圆角 | **20**（radiusLg） |
| 底部导航高 | **84**（navHeight） |
| 输入框/大圆角 | 24（radiusXl） |
| 列表项圆角 | 16（radiusMd） |
| 间距阶梯 | 4 / 8 / 12 / 16 / 20 / 24 / 32 |

阴影：`softShadow = 8% 冷灰蓝，offset (0, 4)，blur 16，spread -2`；卡片加重版 offset (0, 6)、blur 20、spread -4。

## 4. 字体（qyTextTheme）

设计稿字体：**Noto Sans SC**（中文）+ **Outfit**（数字）。当前未强制绑定（避免缺字体），接入方式见 `BUILD.md` 第 5 节。

| 样式 | 字号/行高 | 字重 |
| --- | --- | --- |
| displayLarge | 40/48 | 700 |
| headlineLarge | 28/36 | 700 |
| headlineMedium | 22/30 | 600 |
| titleLarge | 18/26 | 600 |
| bodyLarge | 15/22 | 400 |
| bodyMedium | 13/18 | 400（sub 色） |
| labelLarge | 15/20 | 600 |
| labelMedium | 12/16 | 500 |
| labelSmall | 11/16 | 500（muted 色） |

## 5. 组件清单（qingyun_ui_kit）

| 组件 | 说明 |
| --- | --- |
| `QyIcon` | 40 个内联 SVG 图标（`QyIcons` 常量），无需资源文件 |
| `QyFrost` / `QyFrostAppBar` | 磨砂玻璃容器 / 磨砂应用栏（BackdropFilter + 半透明面） |
| `QyTintedIcon` / `QyTintedIconCircle` | 彩色图标：圆角浅色底 + 同族深色图形（`QyHues` 九色族） |
| `QyButton` | 四态：primary（蓝灰底白字）/ secondary / outline / disabled，高 52 胶囊 |
| `QyCard` | 白底圆角 20 卡片 + 细描边 + 浅色投影；`color` 可传 `surfaceSoft` |
| `QyListTile` | 64 高文件列表项（图标 + 标题 + 副标题 + trailing） |
| `QyProgressBar` | 6 高胶囊进度条（可调高度），主色轨道 |
| `QyBottomNav` | 纯白底部导航（首页/文件/传输/我的），选中态主色 + 底部小圆点 |
| `QyEmptyState` | 空状态（图标 + 标题 + 描述 + 可选按钮） |
| `showQyToast` | 顶部 Overlay Toast（成功/失败两种） |
| `qyLightTheme()` | MaterialApp 主题（Material 3） |
| `QyRoutes` | 12 个场景路由常量 |

## 6. 场景与路由（12 个）

| 路由 | 场景 | 实现文件 |
| --- | --- | --- |
| `/` | 启动页 | `features/splash/splash_screen.dart` |
| `/home` | 首页（功能入口：相册/文件/视频/同步/分类 + 最近文件） | `features/home/home_screen.dart` |
| `/files` | 文件分类与列表 | `features/files/files_screen.dart` |
| `/transfers` | 传输任务 | `features/transfers/transfers_screen.dart` |
| `/profile` | 个人中心 | `features/profile/profile_screen.dart` |
| `/transfer-files` | 上传 / 下载 | `features/transfer/transfer_files_screen.dart` |
| `/search` | 搜索 | `features/search/search_screen.dart` |
| `/preview` | 预览 | `features/preview/preview_screen.dart` |
| `/share` | 分享与权限 | `features/share/share_screen.dart` |
| `/trash` | 回收站 | `features/trash/trash_screen.dart` |
| `/storage` | 容量管理 | `features/storage/storage_screen.dart` |
| `/states` | 空状态与反馈 | `features/states/states_screen.dart` |

底部四 Tab：`/home`、`/files`、`/transfers`、`/profile`（`StatefulShellRoute.indexedStack` + `QyBottomNav`），其余为独立推入页面。

## 7. 图标体系

- 图标名常量：`QyIcons`（cloud/home/folder/transfer/user/search/upload/download/share/trash/… 共 40 个）
- SVG 路径内置于 `QyIconPaths`，通过 `QyIcon(name, size, color)` 渲染，颜色自动替换描边色
- 彩色图标：`QyTintedIcon(icon, hue: QyHues.blue, size: 44)` —— 浅色圆角底 + 深色描边图形；功能入口、菜单、设置项等统一使用
- 文件分类色：图片=蓝 `sky`、文档=金 `gold`、视频=紫 `violet`、音乐=青 `mint`、压缩包=珊瑚 `coral`
