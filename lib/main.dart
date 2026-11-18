import 'app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 不再启用 edgeToEdge：部分 Android 机型下内容会顶进状态栏，导致
  // 时间/信号图标与页内大标题重叠。保留白色状态栏 + 深色图标，
  // 与纯白画布完全融合，SafeArea 也能正常拿到顶部 padding。
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const QingyunApp());
}
