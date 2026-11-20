# 轻云设计规范（DESIGN SPEC）

本规范以《轻云-云盘App原型-v1.html》为**唯一视觉依据**：Flutter 端 8 个页面按原型逐屏 1:1 还原，包含色板、渐变、圆角、字号、间距与图标。原型里没有任何位图资源，所有"图片"均为 CSS 渐变 + 圆角 + 阴影 + Material Icons 字体图标；Flutter 端同样全部用代码绘制（`LinearGradient` / `SweepGradient` / `RadialGradient` + `Icon`），不引入图片资源。

> **数据口径（第 19 步补）**：本规范只约束**视觉骨架**——下文所有色值、圆角、间距、渐变角度、字号、组件尺寸与动效时长都是真实设计度量，逐字保留、不改。页面上的**内容数据一律来自 lanflare 真实接口**（见 `docs/BACKEND.md`）；原型 HTML 里写死的百分比、热搜词、日期分组、VIP 天数、示例条数等只是排版占位，**不是实现依据**，正文中凡提及处均已改成实现口径。原型「文案」仅指静态标签与视觉结构，不含任何编造数值。

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

## 4. 页面结构

### 4.1 原型 8 屏（视觉骨架，逐字对齐原型）

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

底部四 Tab：`/home`、`/files`、`/transfers`、`/profile`（`StatefulShellRoute.indexedStack` + `QyBottomNav`）。上表是原型的 8 个视觉主屏，色板 / 布局 / 组件规范全部适用。

### 4.2 对接真实后端后新增的功能页（沿用同一套设计 token）

第 1~18 步把原型占位全部换成真实数据后，路由表在原 8 屏之外新增了下列**真实功能页**，全部复用本规范的 `QyColors` / `QyTokens` / `Proto*` 组件，没有引入第二套视觉。后端契约见 `docs/BACKEND.md`。

| 路由 | 页面 | 真实能力 |
| --- | --- | --- |
| `/login` | 登录（含 TOTP） | 全局登录态守卫，401 时清凭证后跳回 |
| `/trash` | 回收站 | `GET /api/bin` + 恢复 / 清空（**已是真实页，不再是重定向**） |
| `/my-shares` | 我的分享 | `GET /api/my-shares` + 撤销 |
| `/admin-vip` | 会员管理 | 仅 admin，`GET /api/admin/users` + `POST .../vip` |
| `/security` | 安全中心 | 两步验证 + 账户信息 |
| `/devices` | 登录设备 / API 令牌 | 令牌列表、新建、备注、吊销 |
| ~~`/storage-account`~~ | ~~存储账号绑定~~ | 已移除：后端账号池改造后存储账号由管理员网页端统一管理，App 无此页（2026-11-20 对接核查） |
| `/help` | 帮助与反馈 | 真实 FAQ + 反馈提交 / 回复 |
| `/settings` | 设置 | 服务地址、连接自检（含 `signing_mode`）、本地数据清理 |
| `/scan` | 扫一扫 | 摄像头识别 → 分享解析 → 转存到目录 |
| `/recall-album` | 照片回忆轮播 | `GET /api/recall/album` 真实分组 + 自动续签 |

旧场景路由（`QyRoutes.splash` `/transfer-files` `/share` `/states`，以及 `/gallery` `/all-files` `/videos`）仍 `redirect` 到对应的 8 屏之一，**只为兼容旧链接**，App 内不存在第二套视觉。`/preview` 未携带文件对象时重定向回 `/files`，避免旧占位页重现。

### 逐屏要点

- **首页**：渐变头图（168deg `#E4EEFF→#EFF4FF→#F5F7FB` + 右上薄荷径向光晕）**固定不滚动**（原型 `.hero{flex-shrink:0}`）；其下 `.scroll` 独立滚动 → 容量卡（真实 `used/total` 容量环 + 按 `by_category` 真实占比的四段进度条 + 会员入口）→ 4 宫格快捷入口 → 最近文件横滑（数量随真实文件数）→ 为你推荐回忆渐变卡（`GET /api/recall/daily` 真实聚合，四态）。原型写死的容量环占比、四段固定占比与横滑卡片数均为排版占位，不是实现数据（四段进度条已于第 19 步改为按 `by_category` 真实字节数分配）。实现用 `Stack`：底层固定渐变多铺 38px，滚动区从头图内容底部开始，容量卡第一帧恰好叠进渐变尾部 38px（等价原型 `margin:-38px`），滚动时由滚动区顶部裁切，不会盖住固定头图。
- **横向滚动行（重要约束）**：所有横滑行一律用 `SingleChildScrollView(scrollDirection: horizontal) + Row`，**禁止**「固定高度 `SizedBox` + 横向 `ListView`」。横向 ListView 会把 children 压进 viewport 高度，固定值只要比「上下 padding + 中文行高 + 描边」小 1px，中文字下半截就会被裁掉（传输页 / 全部文件页的筛选胶囊曾出现缺笔画）。`ProtoChipRow` 与首页 `_RecentRow` 均按此实现，高度由内容自然撑开。
- **滚动回弹（重要约束）**：所有 `ListView` 一律用共享常量 `qyProtoScrollPhysics`（`proto_widgets.dart`）= `AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())`。四个 Tab 页改成「固定头部 + `Expanded` 滚动区」后滚动区可能很矮，`AlwaysScrollable` 保证内容不足一屏也能拖；**必须带 `BouncingScrollPhysics` 父级**，由 spring 把越界内容拉回。裸的 `const AlwaysScrollableScrollPhysics()` 基类 `createBallisticSimulation` 在越界时返回 null，松手后内容停在越界位置，表现就是「滑到底 / 内容不足一屏时卡一半、不回弹」。双端统一回弹，不按平台切 Clamping（Clamping 只有拉伸光晕，不是内容归位）。预览页是固定 Column，无需 physics。
- **底部留白**：四个 Tab 页滚动区 `bottom: 96~100`，是给 74 高底部导航预留的遮挡空间，不是多余空白；配合回弹 physics，滚到底松手会归位。
- **卡片内元信息**：`_FileCard` 宽 126、内容宽 106，中文 + 数字 + 单位（如 `x.x MB` 这类真实容量标签）在真机字体下可能折行；用 `FittedBox(scaleDown)` 固定单行完整显示，文件名仍用 `maxLines:1 + ellipsis`。尺寸是设计度量，标签数值来自真实接口，不是写死值。
- **文字行高**：列表行 padding 自适应（原型 `.hot-row` 用 `padding: 11px 0`），不写死 44 高；其余固定高度仅用于纯图标 / 装饰（进度环、甜甜圈、照片块、指示点），不承载文字。搜索页原「热搜榜」已换成 `GET /api/stats/quick` 的真实「最近文件」列表。
- **固定头部（四个 Tab 页的统一约束）**：原型所有 `.nav` / `.hero` / `.me-hero` / `.chip-row` / `.folders` 等头部块均为 `flex-shrink:0`，只有 `.scroll` 滚动。四个 Tab 页一律用 `ColoredBox + Column(crossAxisAlignment: stretch)`：固定块按自然高度排在顶部，余下内容放进 `Expanded(ListView)`，并加 `AlwaysScrollableScrollPhysics` 保证内容不足时也能拖动。各页固定边界（按用户红框确认）：
  - 首页：渐变头图 + 问候语（真实用户名） + 搜索 / 扫一扫 / 头像
  - 全部文件：`ProtoNav` + 筛选胶囊 + 文件夹宫格（数量随真实目录数）；滚动区从「文件 / 当前排序」开始（6 种真实排序，SectionHead 动态显示，不再写死「按修改时间」），FAB 仍 `Positioned` 在右下角
  - 传输：`ProtoNav` + 速度渐变卡（真实运行任务数） + 三个筛选胶囊（进行中 / 已完成 / 失败）；滚动区从第一个任务卡开始
  - 我的：渐变个人头图 + 会员横幅（真实会员状态） + 14 间距；滚动区从「存储空间」卡开始
  - 独立页（搜索 / 容量 / 预览 / 相册）仍为整页滚动，未改
> 下面 7 条描述的是**视觉骨架与区块顺序**（组件尺寸、列数、工具栏数、固定头部 96~100 留白等为设计度量，保留）；括号里的原型示例数值 / 假内容一律**不是**实现数据，实际内容全部由 lanflare 真实接口驱动。

- **文件页**：面包屑 / 目录钻取 → 分类筛选胶囊 → 文件夹宫格（真实数量）→ 文件列表（真实数量，6 种排序）→ 右下 54 渐变 FAB；原型写死的「5 个胶囊 / 2×2 宫格 / 5 行列表」只是排版示意。
- **传输页**：速度渐变条 → 3 个筛选胶囊（进行中 / 已完成 / 失败）→ 真实任务卡（含暂停 / 继续 / 重试 / 重新选文件）→「最近完成」列表（持久化记录，可能跨天，不写死「今天」）。
- **我的**：渐变个人头图（大头像 + 真实会员徽章三态 + 三项真实计数）→ 深色会员横幅（真实会员状态）→ 三组设置卡片 → 页脚；原型里的写死 VIP 天数与统计计数已全部换成 `GET /api/status` 的真实字段。
- **搜索**：搜索框 → 本地搜索历史 → 3 条快捷筛选（`/api/stats/quick` 真实分类计数 + 本地真实运行任务数）→「最近文件」真实列表；原型的「热搜榜（热/新徽标）」与写死分类计数已移除。
- **存储空间**：`SweepGradient` 甜甜圈（真实 `used/total` 占比；原型那组写死分类占比只是排版占位，已移除）→ 2×2 图例（`by_category` 真实 GB 数）→ 清理建议卡（`/api/storage/analyze` 真实分析，无数据显示「暂无清理建议」）→ 查看会员卡（admin 直达会员管理）。
- **预览**：深色屏 + 430 高渐变大图 + 装饰圆 + 指示点 + 元信息 + 5 个工具栏（图片 / 视频 / 音频 / 文本 / PDF 在线渲染，其余格式下载后打开，全部走签名 URL）；430 高与 5 个工具位是设计度量。
- **相册**：我的照片回忆横幅（`/api/recall/album` 真实照片数 → 轮播页）→「全部照片」3 列渐变照片网格（真实云端图片）；原型写死的日期分组标题已移除，3 列是设计度量。

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
