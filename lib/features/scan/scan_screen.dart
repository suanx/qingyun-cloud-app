import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/config/admin_gate.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';

/// 扫一扫：识别 lanflare 分享二维码 → `POST /api/resolve-share` →
/// 选择目标目录 → `POST /api/rent` 转存。
///
/// 扫码原文（链接 / 纯 token / 带说明文字）由后端统一规范化，前端原样传递；
/// 解析响应回显的标准 `code` 再原样传给转存接口。
/// 相机不可用或权限被拒时，页面仍可通过「手动输入分享码」完成同一链路。
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _PermissionState { checking, granted, denied, permanentlyDenied, unsupported }

enum _Stage { scanning, busy, preview, done }

class _ScanScreenState extends State<ScanScreen> {
  final CloudRepository _repo = CloudRepository();
  final TextEditingController _manualController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();

  final MobileScannerController _controller = MobileScannerController();

  _PermissionState _permission = _PermissionState.checking;
  _Stage _stage = _Stage.scanning;
  bool _handled = false;

  String? _error;
  String _lastScan = '';
  ScanResolution? _resolution;
  RentResult? _result;

  List<FolderEntry> _folders = <FolderEntry>[];
  int _targetPid = 0;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _loadFolders();
  }

  @override
  void dispose() {
    _manualController.dispose();
    _pwdController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 权限
  // ---------------------------------------------------------------------------

  Future<void> _requestPermission() async {
    if (mounted) setState(() => _permission = _PermissionState.checking);
    try {
      final PermissionStatus status = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _permission = status.isGranted
            ? _PermissionState.granted
            : (status.isPermanentlyDenied
                ? _PermissionState.permanentlyDenied
                : _PermissionState.denied);
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'scan#permission');
      if (mounted) {
        setState(() => _permission = _PermissionState.unsupported);
      }
    }
  }

  Future<void> _openSettings() async {
    try {
      await openAppSettings();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'scan#openAppSettings');
      if (mounted) {
        showQyToast(context, '无法打开系统设置，请手动开启相机权限',
            success: false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 目录列表（复用第 7 步的 GET /api/folders）
  // ---------------------------------------------------------------------------

  Future<void> _loadFolders() async {
    try {
      final List<FolderEntry> folders = await _repo.listFolders();
      if (!mounted) return;
      setState(() => _folders = folders);
    } catch (error, stack) {
      // 目录列表拉取失败不阻断转存到根目录。
      ErrorReporter.report(error, stack, context: 'scan#folders');
    }
  }

  // ---------------------------------------------------------------------------
  // 扫码 / 解析 / 转存
  // ---------------------------------------------------------------------------

  void _onDetect(BarcodeCapture capture) {
    if (_handled ||
        _stage != _Stage.scanning ||
        _permission != _PermissionState.granted) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String value = barcode.rawValue?.trim() ?? '';
      if (value.isEmpty) continue;
      _handled = true;
      _resolve(value);
      return;
    }
  }

  /// [pwd] 只在蓝奏分享要求提取码时由用户输入，原样回传重新解析。
  Future<void> _resolve(String raw, {String pwd = ''}) async {
    final String value = raw.trim();
    if (value.isEmpty) {
      showQyToast(context, '请先扫码或粘贴分享链接', success: false);
      return;
    }
    if (_stage == _Stage.busy) return;
    setState(() {
      _stage = _Stage.busy;
      _error = null;
      _lastScan = value;
      _resolution = null;
      _result = null;
    });
    try {
      final ScanResolution resolution =
          await _repo.scanResolve(value, pwd: pwd);
      if (!mounted) return;
      setState(() {
        _resolution = resolution;
        _stage = _Stage.preview;
      });
      // 探测失败 / 需要提取码不弹 toast：预览卡里给出真实原因与可操作入口。
    } on ApiException catch (error) {
      if (!mounted) return;
      _failResolve(error.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'scan#resolve');
      if (!mounted) return;
      _failResolve('解析失败：$error');
    }
  }

  /// 用户补填提取码后，用同一份扫码原文重新解析（原文不落地、不拼码）。
  Future<void> _retryWithPassword() async {
    final String pwd = _pwdController.text.trim();
    if (pwd.isEmpty) {
      showQyToast(context, '请输入提取码', success: false);
      return;
    }
    await _resolve(_lastScan, pwd: pwd);
  }

  void _failResolve(String message) {
    setState(() {
      _error = message;
      _stage = _Stage.scanning;
      _handled = false;
    });
    showQyToast(context, message, success: false);
  }

  Future<void> _rent() async {
    final ScanResolution? resolution = _resolution;
    if (resolution == null || !resolution.ready || _stage == _Stage.busy) return;
    setState(() {
      _stage = _Stage.busy;
      _error = null;
    });
    try {
      final RentResult result = resolution.isLanzou
          ? await _repo.importLanzou(resolution.importId!, _targetPid)
          : await _repo.rentShare(resolution.code!, _targetPid);
      if (!mounted) return;
      setState(() {
        _result = result;
        _stage = _Stage.done;
      });
      showQyToast(context, result.summary, success: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _stage = _Stage.preview;
      });
      showQyToast(context, '转存失败：${error.message}', success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'scan#rent');
      if (!mounted) return;
      setState(() {
        _error = '转存失败：$error';
        _stage = _Stage.preview;
      });
      showQyToast(context, '转存失败，请稍后重试', success: false);
    }
  }

  void _rescan() {
    _pwdController.clear();
    setState(() {
      _handled = false;
      _resolution = null;
      _result = null;
      _error = null;
      _lastScan = '';
      _targetPid = 0;
      _stage = _Stage.scanning;
    });
  }

  String get _targetLabel {
    if (_targetPid == 0) return '我的云盘（根目录）';
    for (final FolderEntry folder in _folders) {
      if (folder.id == _targetPid) return folder.path;
    }
    return '#$_targetPid';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        physics: qyProtoScrollPhysics,
        padding: const EdgeInsets.only(bottom: 30),
        children: <Widget>[
          ProtoNav(
            title: '扫一扫',
            subtitle: '扫描分享二维码 · 转存到云盘',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
            ),
            actions: <Widget>[
              ProtoIconButton(
                icon: Icons.refresh,
                onTap: () {
                  _rescan();
                  _loadFolders();
                },
              ),
            ],
          ),
          _IntroCard(),
          const SizedBox(height: 14),
          if (_resolution?.blocker.isNotEmpty ?? false) ...<Widget>[
            _BlockerCard(
              resolution: _resolution!,
              pwdController: _pwdController,
              busy: _stage == _Stage.busy,
              onRetryPassword: () => _retryWithPassword(),
              onRetryProbe: () => _resolve(_lastScan),
              onRescan: () => _rescan(),
            ),
            const SizedBox(height: 14),
          ],
          if (_permission != _PermissionState.granted)
            _PermissionCard(
              state: _permission,
              onRetry: () => _requestPermission(),
              onOpenSettings: () => _openSettings(),
            )
          else
            _CameraCard(
              controller: _controller,
              onDetect: _onDetect,
              busy: _stage == _Stage.busy,
            ),
          const SizedBox(height: 14),
          _ManualCard(
            controller: _manualController,
            busy: _stage == _Stage.busy,
            onSubmit: () => _resolve(_manualController.text),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            _ErrorCard(
              message: _error!,
              raw: _lastScan,
              onDismiss: () {
                setState(() => _error = null);
              },
            ),
          ],
          if (_resolution != null &&
              _resolution!.ready &&
              _stage != _Stage.done) ...<Widget>[
            const SizedBox(height: 14),
            _PreviewCard(
              resolution: _resolution!,
              folders: _folders,
              targetPid: _targetPid,
              targetLabel: _targetLabel,
              busy: _stage == _Stage.busy,
              onTargetChanged: (int pid) => setState(() => _targetPid = pid),
              onRent: () => _rent(),
              onRescan: () => _rescan(),
            ),
          ],
          if (_result != null) ...<Widget>[
            const SizedBox(height: 14),
            _DoneCard(
              result: _result!,
              targetLabel: _targetLabel,
              onViewFiles: () => context.go(QyRoutes.files),
              onRescan: () => _rescan(),
            ),
          ],
          const ProtoFootNote(
            '分享内容由服务端解析；短链接仅在本服务实例有效，蓝奏链接需服务端可访问分享页',
            padding: EdgeInsets.fromLTRB(0, 20, 0, 10),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 卡片组件
// ---------------------------------------------------------------------------

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.qr_code_2, size: 19, color: QyColors.primary),
              SizedBox(width: 9),
              Text('识别分享内容',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: QyColors.ink)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '支持轻云分享码与蓝奏云原生分享链接（含提取码）。'
            '扫码原文由服务端自动判别并解析，选好目标目录即可转存到自己的云盘。',
            style: TextStyle(fontSize: 11, height: 1.5, color: QyColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.state,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final _PermissionState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String message;
    if (state == _PermissionState.checking) {
      title = '正在申请相机权限…';
      message = '首次使用需要允许应用访问摄像头。';
    } else if (state == _PermissionState.permanentlyDenied) {
      title = '相机权限已被永久拒绝';
      message = '请到系统设置中开启相机权限，或直接使用下方手动输入。';
    } else if (state == _PermissionState.unsupported) {
      title = '无法使用相机';
      message = '当前设备或系统未提供相机能力，可使用下方手动输入完成转存。';
    } else {
      title = '需要相机权限';
      message = '扫码识别需要访问摄像头；不授权也可以手动粘贴分享码。';
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.camera_alt_outlined,
                  size: 19, color: QyColors.amberDeep),
              const SizedBox(width: 9),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: QyColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(
                  fontSize: 11, height: 1.5, color: QyColors.muted)),
          const SizedBox(height: 12),
          if (state == _PermissionState.checking)
            const LinearProgressIndicator(minHeight: 2)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.camera, size: 16),
                  label: const Text('重新授权'),
                ),
                if (state == _PermissionState.permanentlyDenied)
                  OutlinedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('去系统设置'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.controller,
    required this.onDetect,
    required this.busy,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF141821),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: const Color(0xFF2A3040)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: MobileScanner(controller: controller, onDetect: onDetect),
          ),
          // 四角扫描框
          const IgnorePointer(child: _ScanFrame()),
          if (busy)
            Positioned.fill(
              child: Container(
                color: const Color(0x99101824),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 10),
                      Text('正在处理…',
                          style: TextStyle(fontSize: 12, color: QyColors.onDark)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: CustomPaint(painter: _FramePainter()),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = QyColors.onDark
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const double len = 22;
    final double w = size.width;
    final double h = size.height;
    // 左上
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    // 右上
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // 左下
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    // 右下
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) => false;
}

class _ManualCard extends StatelessWidget {
  const _ManualCard({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.edit_note, size: 18, color: QyColors.primary),
              SizedBox(width: 8),
              Text('手动输入分享链接',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: QyColors.ink)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '支持 lanflare:// 完整码、/s/ 分享链接、蓝奏云原生分享链接'
            '（https://…lanzou.com/i… 或 /b…），以及带「提取码：xxxx」的说明文字。',
            style: TextStyle(fontSize: 10.5, height: 1.4, color: QyColors.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            minLines: 1,
            autocorrect: false,
            decoration: const InputDecoration(
              isDense: true,
              hintText: '粘贴分享链接或分享码',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 12, color: QyColors.ink),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: busy ? null : onSubmit,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('解析'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.raw,
    required this.onDismiss,
  });

  final String message;
  final String raw;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final String preview = raw.length > 70 ? '${raw.substring(0, 70)}…' : raw;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(13),
      decoration: const BoxDecoration(
        color: QyColors.pinkSoft,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18, color: QyColors.coral),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(message,
                    style: const TextStyle(
                        fontSize: 11.5, color: QyColors.ink)),
                if (raw.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text('识别内容：$preview',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: QyColors.muted)),
                ],
              ],
            ),
          ),
          QyTapScale(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 16, color: QyColors.coral),
          ),
        ],
      ),
    );
  }
}

/// 解析结果暂不能转存时的可操作提示卡。
///
/// 只展示后端给的真实原因，不编造名称 / 大小 / 文件数：
/// - 需要提取码 → 输入框 + 用同一份原文重新解析；
/// - 外呼探测失败 → 显示真实错误 + 重试（VPS 可能暂时访问不到分享页）；
/// - 文件夹分享列不出文件 → 提示检查提取码或链接有效性。
class _BlockerCard extends StatelessWidget {
  const _BlockerCard({
    required this.resolution,
    required this.pwdController,
    required this.busy,
    required this.onRetryPassword,
    required this.onRetryProbe,
    required this.onRescan,
  });

  final ScanResolution resolution;
  final TextEditingController pwdController;
  final bool busy;
  final VoidCallback onRetryPassword;
  final VoidCallback onRetryProbe;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final bool needsPassword = resolution.isLanzou && resolution.needsPassword;
    final String title = needsPassword ? '需要提取码' : '暂时无法转存';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: QyColors.amberSoft,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.info_outline, size: 18, color: QyColors.amberDeep),
              const SizedBox(width: 9),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: QyColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            resolution.blocker,
            style: const TextStyle(
                fontSize: 11, height: 1.5, color: QyColors.ink),
          ),
          if (resolution.isLanzou && resolution.name.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text('识别到：${resolution.name}',
                style: const TextStyle(fontSize: 10.5, color: QyColors.muted)),
          ],
          if (needsPassword) ...<Widget>[
            const SizedBox(height: 10),
            TextField(
              controller: pwdController,
              autocorrect: false,
              obscureText: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: '提取码',
                hintText: '填写分享方提供的提取码',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12.5, color: QyColors.ink),
              onSubmitted: (_) {
                if (!busy) onRetryPassword();
              },
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: busy ? null : onRescan,
                icon: const Icon(Icons.qr_code_scanner, size: 16),
                label: const Text('重新扫描'),
              ),
              ElevatedButton.icon(
                onPressed: busy
                    ? null
                    : (needsPassword ? onRetryPassword : onRetryProbe),
                icon: Icon(
                    needsPassword ? Icons.key : Icons.refresh,
                    size: 16),
                label: Text(needsPassword ? '验证并继续' : '重试解析'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.resolution,
    required this.folders,
    required this.targetPid,
    required this.targetLabel,
    required this.busy,
    required this.onTargetChanged,
    required this.onRent,
    required this.onRescan,
  });

  final ScanResolution resolution;
  final List<FolderEntry> folders;
  final int targetPid;
  final String targetLabel;
  final bool busy;
  final ValueChanged<int> onTargetChanged;
  final VoidCallback onRent;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.check_circle_outline,
                  size: 18, color: QyColors.mintDeep),
              SizedBox(width: 8),
              Text('已识别分享内容',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: QyColors.ink)),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(
              label: '来源', value: resolution.source.label),
          if (resolution.isLanzou && resolution.host.isNotEmpty)
            _InfoLine(label: '分享站点', value: resolution.host),
          _InfoLine(
              label: '名称',
              value: resolution.name.isEmpty ? '—' : resolution.name),
          _InfoLine(label: '类型', value: resolution.typeLabel),
          _InfoLine(
              label: '大小',
              value: CloudRepository.humanSize(resolution.sizeBytes)),
          _InfoLine(label: '目标目录', value: targetLabel),
          const SizedBox(height: 6),
          Text(
            resolution.isLanzou
                ? '蓝奏分享由服务端读取分享页并暂存探测结果，转存时用一次性凭证提交；'
                    '文件按懒加载方式入库，下载时才解析直链。'
                : '服务端已把扫码原文规范化为标准分享码，转存时原样回传。',
            style: const TextStyle(fontSize: 10.5, color: QyColors.muted),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: targetPid,
            isDense: true,
            decoration: const InputDecoration(
              labelText: '转存到',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<int>>[
              const DropdownMenuItem<int>(
                value: 0,
                child: Text('我的云盘（根目录）',
                    style: TextStyle(fontSize: 12.5)),
              ),
              for (final FolderEntry folder in folders)
                DropdownMenuItem<int>(
                  value: folder.id,
                  child: Text(folder.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5)),
                ),
            ],
            onChanged: (int? value) {
              if (value != null) onTargetChanged(value);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: busy ? null : onRescan,
                icon: const Icon(Icons.qr_code_scanner, size: 16),
                label: const Text('重新扫描'),
              ),
              // 转存会写入 VFS 节点，普通用户为只读。深链直达 /scan 时同样
              // 保护，但解析结果仍可查看（纯读），不是把整页锁死。
              AdminOnly(
                fallback: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '当前为只读账号，转存需管理员',
                    style: TextStyle(fontSize: 12.5, color: QyColors.muted),
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onRent,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(busy ? '转存中…' : '转存到云盘'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({
    required this.result,
    required this.targetLabel,
    required this.onViewFiles,
    required this.onRescan,
  });

  final RentResult result;
  final String targetLabel;
  final VoidCallback onViewFiles;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.task_alt, size: 19, color: QyColors.mintDeep),
              SizedBox(width: 9),
              Text('转存完成',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: QyColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Text(result.summary,
              style: const TextStyle(fontSize: 12.5, color: QyColors.ink)),
          const SizedBox(height: 6),
          _InfoLine(label: '保存位置', value: targetLabel),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onRescan,
                icon: const Icon(Icons.qr_code_scanner, size: 16),
                label: const Text('继续扫描'),
              ),
              ElevatedButton.icon(
                onPressed: onViewFiles,
                icon: const Icon(Icons.folder_open_outlined, size: 16),
                label: const Text('查看文件'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 66,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: QyColors.muted)),
          ),
          Expanded(
            child: Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: QyColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: child,
    );
  }
}
