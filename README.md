# 轻云 · 移动端云盘（qingyun-cloud-app）

基于「轻云」高保真设计稿与 `qingyun_ui_kit` 组件骨架从零搭建的 **Android Flutter 应用**。由 GitHub Actions 自动打包 APK 产物，本地无需安装打包环境。

## 技术栈（与设计资料约定一致）

| 项 | 选型 | 说明 |
| --- | --- | --- |
| 框架 | Flutter stable 3.24.5 | Dart SDK `>=3.0.0 <4.0.0` |
| 设计系统 | `packages/qingyun_ui_kit`（path 依赖） | 主题、组件、路由常量、40 个内联 SVG 图标 |
| 路由 | `go_router ^14` | 4 个底部 Tab 用 `StatefulShellRoute`，另有 6 个独立页面 |
| 图标 | `flutter_svg`（随 ui_kit） | SVG 以内联字符串内置，无需资源文件 |
| 网络 | `dio 5.4.0` | lanflare 原生 JSON、Bearer 令牌 / 会话 Cookie 鉴权、错误映射 |
| CI | GitHub Actions | `android-build` / `release` 两条工作流，仅构建 Android APK |

设计基调：纯白背景 `#FFFFFF`、钢青蓝灰主色 `#4A7386`、彩色图标体系（`QyTintedIcon` 九色族）；全局磨砂玻璃质感（`QyFrost`：背景高斯模糊 + 半透明面 + 细描边），按钮高 52、卡片圆角 20、底部导航高 84、8% 冷灰蓝柔和阴影。详见 `docs/DESIGN_SPEC.md`。

## 目录结构

```
qingyun-cloud-app/
├── android/                     # Android 宿主工程（Gradle 8.3 + AGP 8.1 + Kotlin）
├── lib/
│   ├── main.dart                # 入口
│   ├── app/app.dart             # MaterialApp.router
│   ├── core/
│   │   ├── config/              # AppConfig（BaseUrl、超时、上传阈值）
│   │   ├── network/             # ApiClient / ApiException / TokenStore / CloudRepository
│   │   ├── models/              # CloudFile / StorageSummary / TransferTask
│   │   └── router/              # go_router 路由表 + 底部导航 Shell
│   └── features/                # 业务页面（首页 / 文件 / 传输 / 我的 / 搜索 / 预览 等）
├── packages/qingyun_ui_kit/     # 设计稿抽取的组件骨架（原样集成）
├── .github/workflows/           # Android 打包工作流
└── docs/                        # BUILD / BACKEND / DESIGN_SPEC 文档
```

## 快速开始

App 所有数据均来自真实后端，运行前需按 `docs/BACKEND.md` 部署 lanflare；部署到自建 VPS 后在「我的 → 设置 → 服务地址」填写域名即可（默认地址在 `AppConfig.apiBaseUrl`），无需改代码。

```bash
git clone https://github.com/<your-account>/qingyun-cloud-app.git
cd qingyun-cloud-app
flutter pub get
flutter run                 # 真机或模拟器运行
```

启动后未登录会先进入登录页，使用 lanflare 账号登录；接口约定、鉴权与错误处理见 `docs/BACKEND.md`。

## Android 打包（本地不装环境也可以）

| 方式 | 操作 | 产物 |
| --- | --- | --- |
| 推送 main/beta | GitHub Actions `android-build` 自动构建 | `app-release.apk`（Artifact） |
| 打 tag `v*` | `release` 工作流构建并创建 GitHub Release | `app-release.apk` 随 Release 附件下载 |
| 手动触发 | Actions 页面 `Run workflow` | 同推送 |

> `android-build` 的 Artifact 是未配置 keystore 时的 debug 签名内部测试包，**不可分发**；
> `release` 工作流会校验 4 个签名 Secrets，只有正式签名包才会挂到 GitHub Release。
> 发版还要求仓库提交 `pubspec.lock`。详见 `docs/BUILD.md`。

## 文档索引

- [docs/BUILD.md](docs/BUILD.md) —— 环境搭建、运行、打包、签名、字体接入
- [docs/BACKEND.md](docs/BACKEND.md) —— 后端对接教程：接口约定、鉴权、错误处理、联调注意事项
- [docs/DESIGN_SPEC.md](docs/DESIGN_SPEC.md) —— 设计规范与组件约定
