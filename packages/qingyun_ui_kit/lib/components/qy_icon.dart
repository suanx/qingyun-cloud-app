import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/qy_colors.dart';

/// Icon name constants matching the 40 SVG icons in the design system.
abstract final class QyIcons {
  static const String cloud = 'cloud'; // 云
  static const String home = 'home'; // 首页
  static const String folder = 'folder'; // 文件夹
  static const String transfer = 'transfer'; // 传输
  static const String user = 'user'; // 我的
  static const String search = 'search'; // 搜索
  static const String upload = 'upload'; // 上传
  static const String download = 'download'; // 下载
  static const String share = 'share'; // 分享
  static const String trash = 'trash'; // 删除
  static const String plus = 'plus'; // 加号
  static const String back = 'back'; // 返回
  static const String close = 'close'; // 关闭
  static const String check = 'check'; // 勾选
  static const String more = 'more'; // 更多
  static const String grid = 'grid'; // 网格
  static const String list = 'list'; // 列表
  static const String star = 'star'; // 星标
  static const String clock = 'clock'; // 时钟
  static const String image = 'image'; // 图片
  static const String doc = 'doc'; // 文档
  static const String video = 'video'; // 视频
  static const String music = 'music'; // 音乐
  static const String zip = 'zip'; // 压缩包
  static const String link = 'link'; // 链接
  static const String lock = 'lock'; // 锁
  static const String eye = 'eye'; // 查看
  static const String edit = 'edit'; // 编辑
  static const String bell = 'bell'; // 通知
  static const String settings = 'settings'; // 设置
  static const String chart = 'chart'; // 容量
  static const String signal = 'signal'; // 信号
  static const String wifi = 'wifi'; // WiFi
  static const String battery = 'battery'; // 电池
  static const String pause = 'pause'; // 暂停
  static const String play = 'play'; // 播放
  static const String refresh = 'refresh'; // 刷新
  static const String info = 'info'; // 信息
  static const String warning = 'warning'; // 警告
  static const String empty = 'empty'; // 空盒
}

/// Inner SVG markup for every icon. Rendered through [QyIcon].
abstract final class QyIconPaths {
  static const Map<String, String> paths = <String, String>{
    'cloud': r'<path d="M6.5 18h11a4 4 0 0 0 .4-7.98A6 6 0 0 0 6.2 8.6 4.7 4.7 0 0 0 6.5 18Z"/>',
    'home': r'<path d="M3 11.2 12 4l9 7.2"/><path d="M5.5 10v9.5h13V10"/><path d="M10 19.5v-5h4v5"/>',
    'folder': r'<path d="M3 7a2 2 0 0 1 2-2h4l2 2.5h8a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>',
    'transfer': r'<path d="M8 20V5m0 0L4 9m4-4 4 4"/><path d="M16 4v15m0 0-4-4m4 4 4-4"/>',
    'user': r'<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.6 3.1-5.5 7-5.5s7 1.9 7 5.5"/>',
    'search': r'<circle cx="10.8" cy="10.8" r="6.3"/><path d="m15.5 15.5 4.2 4.2"/>',
    'upload': r'<path d="M12 16V4m0 0L7.5 8.5M12 4l4.5 4.5"/><path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"/>',
    'download': r'<path d="M12 4v12m0 0 4.5-4.5M12 16l-4.5-4.5"/><path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"/>',
    'share': r'<circle cx="18" cy="6" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="m8.2 10.8 7.6-3.6M8.2 13.2l7.6 3.6"/>',
    'trash': r'<path d="M4 7h16M9 7V5h6v2M6.5 7l1 13h9l1-13"/><path d="M10 11v5m4-5v5"/>',
    'plus': r'<path d="M12 5v14M5 12h14"/>',
    'back': r'<path d="M15 5l-7 7 7 7"/>',
    'close': r'<path d="M6 6l12 12M18 6 6 18"/>',
    'check': r'<path d="m5 12.5 4.5 4.5L19 7"/>',
    'more': r'<circle cx="5" cy="12" r="1.6" fill="#6B5A2A" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="#6B5A2A" stroke="none"/><circle cx="19" cy="12" r="1.6" fill="#6B5A2A" stroke="none"/>',
    'grid': r'<rect x="3.5" y="3.5" width="7" height="7" rx="2"/><rect x="13.5" y="3.5" width="7" height="7" rx="2"/><rect x="3.5" y="13.5" width="7" height="7" rx="2"/><rect x="13.5" y="13.5" width="7" height="7" rx="2"/>',
    'list': r'<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1.4" fill="#6B5A2A" stroke="none"/><circle cx="4.5" cy="12" r="1.4" fill="#6B5A2A" stroke="none"/><circle cx="4.5" cy="18" r="1.4" fill="#6B5A2A" stroke="none"/>',
    'star': r'<path d="M12 3.5 14.6 9l6 .9-4.3 4.2 1 6-5.3-2.8-5.3 2.8 1-6L3.4 9.9l6-.9Z"/>',
    'clock': r'<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5.2l3.4 2"/>',
    'image': r'<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="8.5" cy="9.5" r="1.7"/><path d="m4 17 5-5 3.5 3.5 2.5-2.5 5 5"/>',
    'doc': r'<path d="M6 3h8l4 4v14H6Z"/><path d="M14 3v5h4"/><path d="M9 12h6M9 16h6"/>',
    'video': r'<rect x="3" y="5" width="13" height="14" rx="3"/><path d="m16 10 5-3v10l-5-3"/>',
    'music': r'<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>',
    'zip': r'<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 3v4m3-4v4m3-4v4"/><path d="M12 11v6m0-6h3v6h-3"/>',
    'link': r'<path d="M10 14a4 4 0 0 0 5.7 0l2.3-2.3a4 4 0 0 0-5.7-5.7L11 7.3"/><path d="M14 10a4 4 0 0 0-5.7 0L6 12.3a4 4 0 1 0 5.7 5.7l1.3-1.3"/>',
    'lock': r'<rect x="5" y="10" width="14" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/><circle cx="12" cy="15.5" r="1.4" fill="#6B5A2A" stroke="none"/>',
    'eye': r'<path d="M2.6 12S6 6.5 12 6.5 21.4 12 21.4 12 18 17.5 12 17.5 2.6 12 2.6 12Z"/><circle cx="12" cy="12" r="3"/>',
    'edit': r'<path d="m4 20 4.2-1L19 8.2 15.8 5 5 15.8Z"/><path d="m14 6.8 3.2 3.2"/>',
    'bell': r'<path d="M18 16H6l1.5-2.2V10a4.5 4.5 0 0 1 9 0v3.8Z"/><path d="M10 19h4"/>',
    'settings': r'<circle cx="12" cy="12" r="3.2"/><path d="M12 2.8v2.4M12 18.8v2.4M4.9 4.9l1.7 1.7M17.4 17.4l1.7 1.7M2.8 12h2.4M18.8 12h2.4M4.9 19.1l1.7-1.7M17.4 6.6l1.7-1.7"/>',
    'chart': r'<rect x="4" y="12" width="3.2" height="6" rx="1.2"/><rect x="10.4" y="7" width="3.2" height="11" rx="1.2"/><rect x="16.8" y="10" width="3.2" height="8" rx="1.2"/><path d="M3 21h18"/>',
    'signal': r'<path d="M4 18v-3M9 18v-6M14 18v-9M19 18V6" stroke="#2E2A22" stroke-width="2.2"/>',
    'wifi': r'<path d="M3 9a14 14 0 0 1 18 0M6.5 12.5a9 9 0 0 1 11 0M10 16a3.5 3.5 0 0 1 4 0" stroke="#2E2A22" stroke-width="2.2"/><circle cx="12" cy="19.3" r="1.2" fill="#2E2A22" stroke="none"/>',
    'battery': r'<rect x="2.5" y="7" width="16" height="10" rx="3" stroke="#2E2A22"/><path d="M20.5 10.2v3.6" stroke="#2E2A22" stroke-width="2.4"/><rect x="5" y="9.5" width="9" height="5" rx="1.2" fill="#2E2A22" stroke="none"/>',
    'pause': r'<rect x="7.5" y="5.5" width="3.4" height="13" rx="1.4" fill="#6B5A2A" stroke="none"/><rect x="14" y="5.5" width="3.4" height="13" rx="1.4" fill="#6B5A2A" stroke="none"/>',
    'play': r'<path d="m8 5.5 10 6.5-10 6.5Z" fill="#6B5A2A" stroke="none"/>',
    'refresh': r'<path d="M20 11a8 8 0 1 0-2.4 6.5"/><path d="M20 5v6h-6"/>',
    'info': r'<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5"/><circle cx="12" cy="7.7" r="1.2" fill="#6B5A2A" stroke="none"/>',
    'warning': r'<path d="M12 3.5 22 20H2Z"/><path d="M12 9v5"/><circle cx="12" cy="17.2" r="1.2" fill="#6B5A2A" stroke="none"/>',
    'empty': r'<path d="M4 8h16l-1.2 12H5.2Z"/><path d="m4 8 2-4h12l2 4"/><path d="M9.5 12h5"/>',
  };
}

extension QyColorHex on Color {
  String get svgHex => '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

class QyIcon extends StatelessWidget {
  const QyIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = QyColors.ink,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final raw = QyIconPaths.paths[name];
    assert(raw != null, 'Unknown QyIcon: $name');
    final hex = color.svgHex;
    final body = (raw ?? '').replaceAll('#6B5A2A', hex).replaceAll('#2E2A22', hex);
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'width="$size" height="$size" fill="none" stroke="$hex" '
        'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
        '$body</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
