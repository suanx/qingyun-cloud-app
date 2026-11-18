# 轻云设计规范（DESIGN SPEC）

本规范提炼自《轻云 · 移动端云盘 UI 设计方案》与 `packages/qingyun_ui_kit` 组件骨架，是全部 UI 代码的实现依据。

## 1. 设计基调

- 关键词：纯白 · 钢青蓝灰 · 彩色图标 · 玻璃面质感
- **页面背景为纯白不透明底**；Tab 外壳通过 `QyPageBackground` 统一兜底（纯白 `ColoredBox`），不再叠加任何冷调渐变。早期版本的「空气层」光晕在真机上会让页面顶部出现整片淡蓝雾感，已移除；卡片只靠极淡描边与柔投影浮起
- 主色钢青蓝灰，近黑文字 + 冷灰次级文字
- 功能图标统一为「彩色圆角浅底 + 同族深色描边图形」（`QyTintedIcon`）
- **玻璃面体系**：`QyFrost` 统一入口——
  - **玻璃面模式**（`backdrop: false`，全 App 当前唯一启用）：90% 半透明白 + 细描边 + 柔投影，**无模糊层**，内容 100% 清晰。用于卡片、列表项、空状态、分类胶囊等承载内容的组件；
  - **真磨砂模式**（`backdrop: true`，当前禁用）：玻璃面下叠加 `BackdropFilter` 高斯模糊，透出并虚化背后的滚动内容。原设计仅用于应用栏、底部导航、Toast 浮层等悬浮于内容之上的栏体。
- **当前实现状态（以代码为准）**：`QyFrost.realBlurEnabled` 全局关闭，且 AppBar / 底部导航 / Toast 的调用点已统一改为 `backdrop: false`，运行时不创建任何 `BackdropFilter`；总开关仅作兜底。原因是部分 Android 设备上模糊区域会异常扩大并泄漏到整页（v0.1.2 已复发一次，`RepaintBoundary` 不足以兜底）。重新启用前须完成多机型真机回归验证，并同步修改本节说明，避免再次出现"文档说可用、代码却已全局禁用"的偏差。
- **首页结构**（对齐高保真设计稿）：品牌抬头（轻云 + 圆形浅底搜索/通知）→ 问候语 → 横向概览卡轮播（最近照片 / 存储空间 / 传输任务，3 页 + 胶囊指示器）→ 分类胶囊（相册/文件/视频/分类 + 已同步状态点，选中块在槽位间滑动）→ 最近文件扁平列表（浅底圆角图标 + 细分割线）。概览卡大数字使用 `FittedBox(scaleDown)` 固定单行，杜绝「8.2」折行；底部导航为纯白玻璃面，选中态为主色实心圆**承载白色图标**（不是孤立圆点）。
- **动效规范（全局）**：页面转场由 `QyPageTransitionsBuilder` 统一接管（淡入 + 轻微上滑 + 微缩放，`easeOutCubic`，无灰色 scrim）；M3 默认 `InkSparkle` 圆润波纹；首页各区块按 `qyEntranceStep` 交错淡入上滑；卡片 / 列表行 / 胶囊按压统一走 `QyTapScale` 缩放回弹；分类高亮、指示器宽度、导航选中态圆底与文字颜色均带动画。所有曲线统一 `easeOutCubic`。
- **导航约束**：`/home`、`/files`、`/transfers`、`/profile` 属于 `StatefulShellRoute` 分支，业务内切换一律用 `context.go`（首页「分类」「传输概览」已按此实现）；`push` 会在 shell 之上叠一个页面实例，仅演示中心这类需要独立返回栈的入口使用。因此**所有页面根节点必须自带纯白不透明底**，即使被 push 也不会在转场途中透出下层内容、形成灰色浮层。

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
| 卡片圆角 | **26**（radiusCard） |
| 底部导航高 | **84**（navHeight） |
| 输入框/大圆角 | 24（radiusXl） |
| 列表项圆角 | 20（radiusLg） |
| 间距阶梯 | 4 / 8 / 12 / 16 / 20 / 24 / 32 |

阴影：`softShadow = 8% 冷灰蓝，offset (0, 4)，blur 16，spread -2`；列表项沿用；卡片专用 `cardShadowSoft`：offset (0, 10)、blur 30、spread -10，更轻更柔。

动效时长：`shortMotion` 200ms、`mediumMotion` 320ms、`entranceMotion` 460ms，交错步长 70ms。

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
| `QyFrost` / `QyFrostAppBar` | 玻璃面容器（真磨砂模式已禁用）/ 玻璃面应用栏 |
| `QyPageBackground` | 全局纯白不透明底（Tab 外壳统一包裹，兼作透明兜底） |
| `QyPageTransitionsBuilder` | 全局圆润页面转场（淡入 + 上滑 + 微缩放），在 `qyLightTheme()` 中注册 |
| `QyTapScale` | 统一按压回弹：按下缩至 0.955，松手弹回 |
| `QyTintedIcon` / `QyTintedIconCircle` | 彩色图标：圆角浅色底 + 同族深色图形（`QyHues` 九色族） |
| `QyButton` | 四态：primary（蓝灰底白字）/ secondary / outline / disabled，高 52 胶囊 |
| `QyCard` | 玻璃面卡片（90% 白 + 极淡描边 + 柔投影），圆角 26；`color` 可传 `surfaceSoft` |
| `QyListTile` | 68 高文件列表项（图标 + 标题 + 副标题 + trailing），圆角 20 |
| `QyProgressBar` | 6 高胶囊进度条（可调高度），主色轨道 |
| `QyBottomNav` | 纯白玻璃面底部导航（首页/文件/传输/我的），选中态主色圆底承载白色图标 + 底部小圆点 |
| `QyEmptyState` | 空状态（图标 + 标题 + 描述 + 可选按钮） |
| `showQyToast` | 顶部 Overlay Toast（成功/失败两种） |
| `qyLightTheme()` | MaterialApp 主题（Material 3 + 全局转场 + InkSparkle 波纹） |
| `QyRoutes` | 12 个场景路由常量 |

## 6. 场景与路由（12 个）

| 路由 | 场景 | 实现文件 |
| --- | --- | --- |
| `/` | 启动页 | `features/splash/splash_screen.dart` |
| `/home` | 首页（概览卡轮播 + 分类胶囊 + 最近文件） | `features/home/home_screen.dart` |
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
