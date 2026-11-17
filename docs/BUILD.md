# 搭建与打包文档

## 1. 环境要求（本地运行/开发时）

| 工具 | 版本 | 说明 |
| --- | --- | --- |
| Flutter SDK | stable **3.24.5** | `flutter --version` 确认；与 CI 固定版本一致 |
| Dart | 随 Flutter（3.5.x） | 满足 `>=3.0.0 <4.0.0` |
| Android Studio / SDK | API 34 | 仅运行 Android 端时需要 |
| Xcode | 15+（macOS） | 仅运行 iOS 端时需要 |
| CocoaPods | 1.13+ | iOS 插件集成（flutter 工具会自动生成 Podfile） |

> 本仓库已按“本地不打包”约定配置好 CI。本地只需 `flutter pub get && flutter run` 即可开发调试。

## 2. 本地搭建步骤

```bash
# 1) 获取依赖
flutter pub get

# 2) 静态检查
flutter analyze

# 3) 运行（任选其一）
flutter run                       # 当前连接设备
flutter run -d chrome             # Web 调试（ui_kit 图标为 SVG，同样支持）
```

`qingyun_ui_kit` 通过 `pubspec.yaml` 的 path 依赖引入（`packages/qingyun_ui_kit`），无需发布到 pub.dev。

### 2.1 运行功能演示

```bash
flutter run
# 启动后进入：我的 → 功能演示（全量）；或直接修改 initialLocation 为 /demo
```

演示中心（`lib/demo/`）分组覆盖全部功能：

- **业务场景**：12 个设计稿场景一键直达；
- **组件演示**（`/demo/components`）：所有 qingyun_ui_kit 组件的典型用法与边界值；
- **网络层演示**（`/demo/network`）：App 内启动本地 HTTP 服务（dart:io HttpServer，127.0.0.1 随机端口），7 个用例完整演示 envelop 解析、鉴权头、业务失败、401、超时、404 的实际返回；
- **边界演示**（`/demo/boundary`）：9 个同步用例验证空数据/除零/越界/非法枚举/字段缺失的容错行为。

> 说明：网络演示依赖 `dart:io`，适用于 Android / iOS / 桌面端；Web 端不可用（其余页面不受影响）。

## 3. 仓库自带的三条 GitHub Actions 工作流

| 工作流 | 文件 | 触发条件 | Runner | 产物 |
| --- | --- | --- | --- | --- |
| android-build | `.github/workflows/android-build.yml` | push 到 `main`/`beta`、PR 到 `main`、手动 | `ubuntu-latest` | `app-release.apk` → Artifact `qingyun-android-apk` |
| ios-build | `.github/workflows/ios-build.yml` | 同上 | `macos-latest` | 未签名 IPA → Artifact `qingyun-ios-ipa` |
| release | `.github/workflows/release.yml` | 推送 `v*` tag | ubuntu + macos | APK/IPA 直接挂到 GitHub Release |

### 3.1 通过工作流出包（推荐，本地零环境）

```bash
# 日常构建：直接推送
git push origin main              # 触发 android-build + ios-build

# 发版：打 tag 触发 Release，双端产物自动上传
git tag v0.1.0
git push origin v0.1.0
```

构建产物在 Actions 运行详情页的 **Artifacts** 区块下载；tag 构建的产物在仓库 **Releases** 页面附件下载。

### 3.2 关键步骤说明

- Flutter 版本通过 `subosito/flutter-action@v2` 固定为 `3.24.5`，保证本地与 CI 一致。
- Android 构建先装 Temurin JDK 17，再 `flutter build apk --release`。
- iOS 构建（`ios-build.yml`）分两步：先 `flutter build ios --release --no-codesign` 编译出未签名 `Runner.app`，再把 `Runner.app` 打包为 `Payload/*.ipa` 的未签名 IPA。仓库已包含标准 `ios/Podfile`，CI 中会显式执行 `pod install` 接入 `Flutter.framework`。
- 两条构建工作流均先执行 `flutter analyze` 作为质量门禁。

## 4. 签名配置

### 4.1 Android 正式签名

当前 `android/app/build.gradle` 的 release 构建临时使用 debug 签名（保证 CI 可复现）。正式发版前：

1. 生成 keystore：
   ```bash
   keytool -genkey -v -keystore ~/qingyun-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias qingyun
   ```
2. 在仓库 Settings → Secrets and variables → Actions 添加：
   - `ANDROID_KEYSTORE_BASE64`：keystore 文件的 base64
   - `ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`
3. 在 `android/app/build.gradle` 增加 `signingConfigs.release` 读取这些变量（推荐用 `key.properties` 或环境变量注入），并把 `buildTypes.release.signingConfig` 指向它。
4. 按项目混淆红线评估是否开启 R8；当前 `minifyEnabled = false`，混淆规则见 `android/app/proguard-rules.pro`。

### 4.2 iOS 签名

CI 产出的是未签名 IPA。如需在 CI 直接签名（Ad Hoc / App Store），需要：

1. 导出 p12 证书与 provisioning profile，配置 Secrets：`IOS_P12_BASE64`、`IOS_P12_PASSWORD`、`IOS_PROFILE_BASE64`；
2. 使用 `apple-actions/import-codesign-certs` 导入证书；
3. 构建命令去掉 `--no-codesign`（改用 `flutter build ipa --release --export-method ad-hoc` 等），并在 Xcode 侧配置 `DEVELOPMENT_TEAM`。

## 5. 字体接入（可选，还原设计稿）

设计稿使用 **Noto Sans SC**（中文）与 **Outfit**（数字）。当前 `TextTheme` 未绑定字体以避免缺字体报错。需要完全还原时：

1. 下载字体文件放入 `assets/fonts/`；
2. 在 `pubspec.yaml` 声明：
   ```yaml
   flutter:
     fonts:
       - family: NotoSansSC
         fonts:
           - asset: assets/fonts/NotoSansSC-Regular.ttf
       - family: Outfit
         fonts:
           - asset: assets/fonts/Outfit-Regular.ttf
   ```
3. 在 `packages/qingyun_ui_kit/lib/theme/qy_typography.dart` 的对应样式中设置 `fontFamily`。

## 6. 常见问题

| 现象 | 处理 |
| --- | --- |
| `flutter pub get` 卡在依赖解析 | 确认 `packages/qingyun_ui_kit` 目录存在；删除 `.dart_tool` 后重试 |
| Android 构建报 Gradle 版本问题 | 仓库已提交 Gradle 8.3 wrapper，确认未改动 `gradle-wrapper.properties` |
| iOS `pod install` 失败 | `cd ios && pod repo update`；确认 CocoaPods ≥ 1.13 |
| CI analyze 失败 | 本地先跑 `flutter analyze --fatal-infos` 修复后再推送 |
