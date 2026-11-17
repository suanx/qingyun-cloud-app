# 轻云设计规范（DESIGN SPEC）

本规范提炼自《轻云 · 移动端云盘 UI 设计方案》与 `packages/qingyun_ui_kit` 组件骨架，是全部 UI 代码的实现依据。

## 1. 设计基调

- 关键词：淡黄 · 柔和渐变 · 年轻化
- **全案无紫色**
- 主色暖黄、米白画布、深棕墨色文字

## 2. 色彩（QyColors）

| Token | 值 | 用途 |
| --- | --- | --- |
| `primary` | `#FFC94A` | 主色（按钮、选中态、进度） |
| `primaryDeep` | `#F5A623` | 主色加深（图标、强调） |
| `primaryLight` | `#FFF0BF` | 浅主色（次级按钮、输入框填充） |
| `canvas` | `#FFF8E7` | 全局背景 |
| `surface` | `#FFFFFF` | 卡片/导航面 |
| `surfaceSoft` | `#FFF6DE` | 空状态底 |
| `coral` / `mint` / `sky` | `#FF9F7A` / `#7FD1B9` / `#8EC5E8` | 分类点缀色 |
| `ink` | `#2E2A22` | 主文字 |
| `sub` | `#7C7566` | 次级文字 |
| `muted` | `#A9A08C` | 弱化文字/图标 |
| `border` / `divider` | `#F2E7CC` / `#F5EFE0` | 描边/分割 |
| `success` / `error` | `#49B58C` / `#E96A5B` | 成功/失败 |
| `warmShadow` | `#1FB78A2E`（12% 暖黄） | 统一阴影色 |

渐变：`warmGradient = [#FFD86B, #FFEBAF, #FFF6DC]`，`primaryGradient = [#FFF0BF, #FFF6DC]`。

## 3. 尺寸与形状（QyTokens）

| Token | 值 |
| --- | --- |
| 按钮高度 | **52** |
| 卡片圆角 | **22**（radiusLg） |
| 胶囊导航高 | **62**（navPillHeight，外框总高 95 = navHeight） |
| 输入框/大圆角 | 26（radiusXl） |
| 列表项圆角 | 18（radiusMd） |
| 间距阶梯 | 4 / 8 / 12 / 16 / 20 / 24 / 32 |

阴影：`softShadow = 12% 暖黄，offset (0, 6)，blur 18，spread -4`；卡片加重版 offset (0, 8)、blur 24、spread -6。

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
| `QyButton` | 四态：primary / secondary / outline / disabled，高 52 胶囊 |
| `QyCard` | 白底圆角 22 卡片，可传 `gradient`，默认暖黄投影 |
| `QyListTile` | 64 高文件列表项（图标 + 标题 + 副标题 + trailing） |
| `QyProgressBar` | 6 高胶囊进度条（可调高度） |
| `QyBottomNav` | 底部胶囊导航（首页/文件/传输/我的），active 填充主色 |
| `QyEmptyState` | 空状态（图标 + 标题 + 描述 + 可选按钮） |
| `showQyToast` | 顶部 Overlay Toast（成功/失败两种） |
| `qyLightTheme()` | MaterialApp 主题（Material 3） |
| `QyRoutes` | 12 个场景路由常量 |

## 6. 场景与路由（12 个）

| 路由 | 场景 | 实现文件 |
| --- | --- | --- |
| `/` | 启动页 | `features/splash/splash_screen.dart` |
| `/home` | 首页（容量卡片 + 快捷操作 + 最近文件） | `features/home/home_screen.dart` |
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
- SVG 路径内置于 `QyIconPaths`，通过 `QyIcon(name, size, color)` 渲染，颜色自动替换描边色。
