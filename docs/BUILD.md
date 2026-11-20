# 搭建与打包文档

## 1. 环境要求（本地运行/开发时）

| 工具 | 版本 | 说明 |
| --- | --- | --- |
| Flutter SDK | stable **3.24.5** | `flutter --version` 确认；与 CI 固定版本一致 |
| Dart | 随 Flutter（3.5.x） | 满足 `>=3.0.0 <4.0.0` |
| Android Studio / SDK | API 34 | 仅运行 Android 端时需要 |

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

> App 所有数据来自真实后端，运行前需按 `docs/BACKEND.md` 部署 lanflare；部署到自建 VPS 后在「我的 → 设置 → 服务地址」填写域名即可（默认地址在 `AppConfig.apiBaseUrl`），无需改代码。

## 3. 仓库自带的两条 GitHub Actions 工作流

| 工作流 | 文件 | 触发条件 | Runner | 产物 |
| --- | --- | --- | --- | --- |
| android-build | `.github/workflows/android-build.yml` | push 到 `main`/`beta`、PR 到 `main`、手动 | `ubuntu-latest` | `app-release.apk` → Artifact `qingyun-android-apk` |
| release | `.github/workflows/release.yml` | 推送 `v*` tag | `ubuntu-latest` | `app-release.apk` 直接挂到 GitHub Release |

### 3.1 通过工作流出包（推荐，本地零环境）

```bash
# 日常构建：直接推送
git push origin main              # 触发 android-build

# 发版：打 tag 触发 Release，APK 自动上传
git tag v0.1.0
git push origin v0.1.0
```

构建产物在 Actions 运行详情页的 **Artifacts** 区块下载（debug 签名的内部测试包，不可分发）；
tag 构建的产物在仓库 **Releases** 页面附件下载（由 4 个签名 Secrets 生成 keystore 后的正式签名包）。

### 3.2 关键步骤说明

- Flutter 版本通过 `subosito/flutter-action@v2` 固定为 `3.24.5`，保证本地与 CI 一致。
- Android 构建先装 Temurin JDK 17，再 `flutter build apk --release`。
- `android-build` 工作流先执行 `flutter analyze` 作为质量门禁。

## 4. 签名配置

### Android 正式签名

发版产物必须使用正式签名。`release` 工作流会硬校验签名 Secrets，缺失即拒绝发版，
不会再出现用公开 debug key 签名的 Release 包。

1. 生成 keystore：
   ```bash
   keytool -genkey -v -keystore ~/qingyun-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias qingyun
   ```
2. 在仓库 Settings → Secrets and variables → Actions 添加 4 个 Secrets：
   - `ANDROID_KEYSTORE_BASE64`：keystore 文件的 base64（`base64 -w0 qingyun-release.jks`）
   - `ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`
3. CI 会把 keystore 解码到 `android/app/qingyun-release.jks`，并生成 `android/key.properties`；
   `build.gradle` 检测到该文件即启用 `signingConfigs.release`。两者均已 gitignore，**绝不入库**。
4. 本地打正式包时，把 keystore 放到 `android/app/` 并自行创建 `android/key.properties`：
   ```properties
   storeFile=qingyun-release.jks
   storePassword=<store password>
   keyAlias=<key alias>
   keyPassword=<key password>
   ```
5. 未配置 keystore 时 `build.gradle` 回退 debug 签名，仅供本地 / `android-build` 内部测试，
   **该 Artifact 不可分发、不可上架**。按项目混淆红线评估是否开启 R8；当前
   `minifyEnabled = false`，混淆规则见 `android/app/proguard-rules.pro`。

> 发版还要求仓库提交 `pubspec.lock`：CI 用 `flutter pub get` + `git diff --exit-code`
> 校验依赖解析未被改写，缺失或漂移都会让 `release` 工作流失败。

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
| CI analyze 失败 | 本地先跑 `flutter analyze --fatal-infos` 修复后再推送 |
