# 轻云 Flutter UI Kit

按「轻云」高保真设计稿抽取的基础主题与组件骨架，可直接接入 `orion_agent`。

## 目录

- `lib/theme/` — 色彩、字体、圆角、间距、阴影与 `ThemeData`
- `lib/components/` — 图标、按钮、卡片、列表项、进度条、底部导航、空状态、Toast
- `lib/router/` — 页面路由路径常量（`QyRoutes`）

## 接入方式

1. 将本目录复制到项目内（例如 `packages/qingyun_ui_kit`）
2. 在 `pubspec.yaml` 添加：

```yaml
dependencies:
  qingyun_ui_kit:
    path: packages/qingyun_ui_kit
```

3. 在 `MaterialApp` 使用主题：

```dart
MaterialApp(
  theme: qyLightTheme(),
  home: MyHomePage(),
)
```

4. 导入组件：

```dart
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
```

## 图标

40 个 SVG 图标以内联字符串方式内置，无需额外资源文件：

```dart
QyIcon(QyIcons.cloud, size: 24, color: QyColors.ink)
```

图标名常量定义在 `QyIcons`，SVG 路径定义在 `QyIconPaths`。

## 字体

设计稿使用 Noto Sans SC（中文）与 Outfit（数字）。当前 TextTheme 未强制绑定字体，避免缺失字体报错。若需完全一致，把字体文件加入 `pubspec.yaml` 后，在 `qy_typography.dart` 对应样式中设置 `fontFamily`。

## 约定

- 全案无紫色；主色 `#FFC94A`，背景 `#FFF8E7`
- 按钮高度 52，卡片圆角 22，胶囊导航高 62
- 阴影使用 12% 暖黄色，偏移 y+6、模糊 18
