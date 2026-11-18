# 轻云设计规范（DESIGN SPEC）

本规范以《轻云-云盘App原型-v1.html》为**唯一视觉依据**：Flutter 端 8 个页面按原型逐屏 1:1 还原，包含色板、渐变、圆角、字号、间距、文案与图标。原型里没有任何位图资源，所有"图片"均为 CSS 渐变 + 圆角 + 阴影 + Material Icons 字体图标；Flutter 端同样全部用代码绘制（`LinearGradient` / `SweepGradient` / `RadialGradient` + `Icon`），不引入图片资源。

## 1. 设计基调

- 关键词：**亮蓝 · 薄荷绿 · 琥珀 · 紫 · 粉 · 浅灰蓝画布**
- 页面背景 `--bg #F5F7FB`；卡片纯白 `#FFFFFF`；顶部分割线 `#EEF2F7`
- 主色 `#2F6BFF`，主色深 `#1E4FD8`，主色浅 `#EAF1FF`；文字 `#101828` / `#667085` / `#98A2B3`
- 强调色族：`mint #22C7AC` / `amber #FFB020` / `violet #8C7BFF` / `pink #FF7AA2`，各配 soft 浅底
- 图标统一使用 **Flutter 内置 Material Icons**（`Icons.*`），与原型 `material-icons` 字体图标一一对应
- 状态栏透明 + `edgeToEdge`，渐变头图铺满到状态栏；各页面顶部自带 54~58 的 padding 避开系统图标
- `QyFrost.realBlurEnabled` 保持全局关闭：原型 tabbar 的 `backdrop-filter: blur(14px)` 在白底上几乎不可见，实现为 94% 白 + 顶部分割线，避免重蹈"整页雾化"的覆辙

## 2. 色板（QyColors）

| Token | 值 | 原型变量 |
| --- | --- | --- |
| `primary` / `primaryDeep` / `primaryLight` | `#2F6BFF` / `#1E4FD8` / `#EAF1FF` | --primary / --primary-deep / --primary-soft |
| `blueLight` | `#4C8DFF` | 渐变起始色 |
| `mint` / `mintSoft` / `mintDeep` | `#22C7AC` / `#E4F8F4` / `#12A88F` | --mint / --mint-soft |
| `amber` / `amberSoft` / `amberDeep` | `#FFB020` / `#FFF4E0` / `#E08A00` | --amber / --amber-soft |
| `violet` / `violetSoft` / `violetDeep` | `#8C7BFF` / `#F0EDFF` / `#7B67F0` | --violet / --violet-soft |
| `pink` / `pinkSoft` / `pinkDeep` | `#FF7AA2` / `#FFEDF2` / `#E04F7C` | --pink / --pink-soft |
| `canvas` / `surface` / `surfaceSoft` | `#F5F7FB` / `#FFFFFF` / `#F5F7FB` | --bg / --card |
| `ink` / `sub` / `muted` | `#101828` / `#667085` / `#98A2B3` | --text / --sub / --tert |
| `border` / `divider` | `#EEF2F7` / `#F6F8FC` | --line / 列表分隔 |
| `heroLabel` / `hint` / `track` / `chevron` / `darkBg` | `#7A8AA8` / `#C3CBD9` / `#EFF3FA` / `#D2D9E5` / `#0B0F16` | 辅助色 |

## 3. 尺寸与形状（QyTokens）

| Token | 值 |
| --- | --- |
| 圆角阶梯 | 10（r-sm）/ 14（r-md）/ 18（r-lg）/ 24（r-xl）/ 20（卡片常用）/ 999（胶囊） |
| 底部导航高 | **74**（padding 8 / 8 / 18） |
| 状态栏占位 | 48（nav / hero 顶部 padding 54 / 58） |
| 间距阶梯 | 4 / 8 / 12 / 16 / 20 / 24 / 32 |
| 阴影 | `softShadow = rgba(31,72,153,.16)`；容量卡 offset (0,10) blur 26 spread -8 |

## 4. 8 个页面

| 序号 | 场景 | 路由 | 实现文件 |
| --- | --- | --- | --- |
| 01 | 首页 · 存储概览 | `/home` | `features/home/home_screen.dart` |
| 02 | 全部文件 | `/files` | `features/files/files_screen.dart` |
| 03 | 传输中心 | `/transfers` | `features/transfers/transfers_screen.dart` |
| 04 | 我的 | `/profile` | `features/profile/profile_screen.dart` |
| 05 | 搜索 | `/search` | `features/search/search_screen.dart` |
| 06 | 存储空间 | `/storage` | `features/storage/storage_screen.dart` |
| 07 | 文件预览（深色） | `/preview` | `features/preview/preview_screen.dart` |
| 08 | 相册 | `/album` | `features/album/album_screen.dart` |

底部四 Tab：`/home`、`/files`、`/transfers`、`/profile`（`StatefulShellRoute.indexedStack` + `QyBottomNav`）。原型之外的旧场景路由（`/gallery`、`/all-files`、`/videos`、`/transfer-files`、`/share`、`/trash`、`/states`、`/demo*`、`/`）统一 `redirect` 到上述 8 屏，保证 App 内不存在第二套视觉。

### 逐屏要点

- **首页**：渐变头图（168deg `#E4EEFF→#EFF4FF→#F5F7FB` + 右上薄荷径向光晕）**固定不滚动**（原型 `.hero{flex-shrink:0}`）；其下 `.scroll` 独立滚动 → 容量卡（68% 环 + 四段进度条 + 升级）→ 4 宫格快捷入口 → 最近文件横滑 4 卡 → 为你推荐回忆渐变卡。实现用 `Stack`：底层固定渐变多铺 38px，滚动区从头图内容底部开始，容量卡第一帧恰好叠进渐变尾部 38px（等价原型 `margin:-38px`），滚动时由滚动区顶部裁切，不会盖住固定头图。
- **横向滚动行（重要约束）**：所有横滑行一律用 `SingleChildScrollView(scrollDirection: horizontal) + Row`，**禁止**「固定高度 `SizedBox` + 横向 `ListView`」。横向 ListView 会把 children 压进 viewport 高度，固定值只要比「上下 padding + 中文行高 + 描边」小 1px，中文字下半截就会被裁掉（传输页 / 全部文件页的筛选胶囊曾出现缺笔画）。`ProtoChipRow` 与首页 `_RecentRow` 均按此实现，高度由内容自然撑开。
- **卡片内元信息**：`_FileCard` 宽 126、内容宽 106，中文 + 数字 + 单位在真机字体下可能折行（`4.2 MB` 被拆成两行）；用 `FittedBox(scaleDown)` 固定单行完整显示，文件名仍用 `maxLines:1 + ellipsis`。
- **文字行高**：热搜行 `.hot-row` 用 `padding: 11px 0` 自适应，不写死 44 高；其余固定高度仅用于纯图标 / 装饰（进度环、甜甜圈、照片块、指示点），不承载文字。
- **文件页**：面包屑导航 → 5 个筛选胶囊 → 2×2 文件夹宫格 → 5 行文件列表 → 右下 54 渐变 FAB
- **传输页**：速度渐变条 → 3 个筛选胶囊 → 3 个进行中任务（渐变进度）→ 今天已完成 3 项
- **我的**：渐变个人头图（大头像 + VIP 标签 + 三组统计）→ 深色 VIP 横幅 → 三组设置卡片 → 页脚
- **搜索**：搜索框 → 历史标签 → 热搜榜（带"热/新"徽标）→ 3 条快捷筛选
- **存储空间**：`SweepGradient` 甜甜圈（24.4% / 20.2% / 13.5% / 9.9%）→ 2×2 图例 → 清理卡片 → 升级卡
- **预览**：深色屏 + 430 高渐变大图 + 装饰圆 + 指示点 + 元信息 + 5 个工具栏
- **相册**：回忆横幅 → 今天 / 本周 / 2025 年 10 月三组 3 列渐变照片网格

## 5. 动效

- 页面转场 `QyPageTransitionsBuilder`：`cubic-bezier(.22,.9,.3,1)`、320ms、淡入 + 上滑 10px + 缩放 .995，与原型 `@keyframes screenIn` 一致
- 全部交互走 `QyTapScale` 按压回弹；筛选 chip、导航选中色、Toast 淡入均带动画
- Toast 屏幕居中、深色半透明、1.9 秒消失

## 6. 组件清单

| 组件 | 说明 |
| --- | --- |
| `ProtoText` / `ProtoNav` / `ProtoSectionHead` / `ProtoChip` / `ProtoTypeIcon` / `ProtoIconButton` / `ProtoFootNote` | `lib/widgets/proto_widgets.dart`：原型通用排版与组件 |
| `QyBottomNav` | 4 Tab 白色 94% 底 + 蓝色选中态，高 74 |
| `QyTapScale` / `qyPageTransitionsTheme` | 按压回弹 / 全局圆润转场 |
| `showQyToast` | 居中 Toast |
| `QyColors` / `QyTokens` / `qyLightTheme()` | 原型色板、尺寸 token、Material 3 主题 |
