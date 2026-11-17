# 轻云 · 移动端云盘（qingyun-cloud-app）

基于「轻云」高保真设计稿与 `qingyun_ui_kit` 组件骨架从零搭建的 **Android + iOS 双端 Flutter 应用**。一套代码双端运行，由 GitHub Actions 自动打包 APK / IPA 产物，本地无需安装打包环境。

## 技术栈（与设计资料约定一致）

| 项 | 选型 | 说明 |
| --- | --- | --- |
| 框架 | Flutter stable 3.24.5 | Dart SDK `>=3.0.0 <4.0.0` |
| 设计系统 | `packages/qingyun_ui_kit`（path 依赖） | 主题、组件、路由常量、40 个内联 SVG 图标 |
| 路由 | `go_router ^14` | 12 个场景路由，底部四 Tab 用 `StatefulShellRoute` |
| 图标 | `flutter_svg`（随 ui_kit） | SVG 以内联字符串内置，无需资源文件 |
| 网络 | `dio ^5` | 统一 envelop 解析、Bearer 鉴权、错误映射 |
| CI | GitHub Actions | `android-build` / `ios-build` / `release` 三条工作流 |

设计基调：暖黄 `#FFC94A`、米白背景 `#FFF8E7`、全案无紫色；按钮高 52、卡片圆角 22、胶囊导航高 62、12% 暖黄柔和阴影。详见 `docs/DESIGN_SPEC.md`。

## 目录结构

```
qingyun-cloud-app/
├── android/                     # Android 宿主工程（Gradle 8.3 + AGP 8.1 + Kotlin）
├── ios/                         # iOS 宿主工程（Runner.xcodeproj）
├── lib/
│   ├── main.dart                # 入口
│   ├── app/app.dart             # MaterialApp.router
│   ├── core/
│   │   ├── config/              # AppConfig（BaseUrl、mock 开关）
│   │   ├── network/             # ApiClient / ApiException / TokenStore / CloudRepository
│   │   ├── models/              # CloudFile / StorageSummary / TransferTask
│   │   └── router/              # go_router 路由表 + 底部导航 Shell
│   └── features/                # 12 个场景页面（splash/home/files/transfer/…）
├── packages/qingyun_ui_kit/     # 设计稿抽取的组件骨架（原样集成）
├── .github/workflows/           # 双端打包工作流
└── docs/                        # BUILD / BACKEND / DESIGN_SPEC 文档
```

## 快速开始

```bash
git clone https://github.com/<your-account>/qingyun-cloud-app.git
cd qingyun-cloud-app
flutter pub get
flutter run                 # 真机或模拟器运行
```

无需任何后端即可运行：默认 `AppConfig.useMockData = true`，页面使用内置示例数据。接入真实后端见 `docs/BACKEND.md`。

## 双端打包（本地不装环境也可以）

| 方式 | 操作 | 产物 |
| --- | --- | --- |
| 推送 main/beta | GitHub Actions `android-build` 自动构建 | `app-release.apk`（Artifact） |
| 推送 main/beta | GitHub Actions `ios-build` 自动构建 | 未签名 `*.ipa`（Artifact） |
| 打 tag `v*` | `release` 工作流构建并创建 GitHub Release | APK + IPA 随 Release 附件下载 |
| 手动触发 | Actions 页面 `Run workflow` | 同推送 |

详细说明与签名配置见 `docs/BUILD.md`。

## 文档索引

- [docs/BUILD.md](docs/BUILD.md) —— 环境搭建、运行、打包、签名、字体接入
- [docs/BACKEND.md](docs/BACKEND.md) —— 后端对接教程：接口约定、鉴权、错误处理、联调注意事项
- [docs/DESIGN_SPEC.md](docs/DESIGN_SPEC.md) —— 设计规范与组件约定
