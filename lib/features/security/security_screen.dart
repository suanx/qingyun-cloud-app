import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';
import '../../widgets/qr_code_view.dart';

/// 安全中心：`GET /api/status` + `GET /api/security/2fa` +
/// `POST /api/security/2fa/{setup,enable,disable}`。
///
/// 两步验证开启后，登录页已支持填写 6 位验证码，不会把自己锁在门外。
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final CloudRepository _repo = CloudRepository();
  TwoFactorStatus? _twoFactor;
  AccountStatus? _account;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final twoFactor = await _repo.twoFactorStatus();
      if (!mounted) return;
      setState(() => _twoFactor = twoFactor);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'security#2fa');
      if (mounted) setState(() => _twoFactor = null);
    }
    try {
      final account = await _repo.accountStatus();
      if (!mounted) return;
      setState(() => _account = account);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'security#account');
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 开启 / 重新绑定：拉二维码矩阵 → 展示 → 输入 6 位码 → enable。
  Future<void> _startEnrollment() async {
    if (_busy) return;
    setState(() => _busy = true);
    final TextEditingController codeController = TextEditingController();
    try {
      final setup = await _repo.twoFactorSetup();
      if (!mounted) return;
      final code = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(setup.alreadyEnabled ? '重新绑定验证器' : '开启两步验证'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (setup.alreadyEnabled)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      '重新绑定会替换验证器里的旧条目，请在验证器 App 中删除旧账号。',
                      style: TextStyle(fontSize: 11.5, color: QyColors.coral),
                    ),
                  ),
                const Text('用验证器 App 扫码，或手动输入下方密钥：',
                    style: TextStyle(fontSize: 11.5, color: QyColors.muted)),
                const SizedBox(height: 12),
                if (setup.hasQr)
                  Center(
                    child: QrCodeView(
                      modules: setup.qrModules,
                      size: setup.qrSize,
                      side: 190,
                    ),
                  )
                else
                  const Text('二维码生成失败，请使用下方密钥手动绑定',
                      style: TextStyle(fontSize: 11.5, color: QyColors.coral)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: QyColors.canvas,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: SelectableText(
                    setup.groupedSecret,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: QyColors.ink),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: setup.secret));
                    if (dialogContext.mounted) {
                      showQyToast(dialogContext, '密钥已复制', success: true);
                    }
                  },
                  icon: const Icon(Icons.copy, size: 15),
                  label: const Text('复制密钥', style: TextStyle(fontSize: 11.5)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '输入验证器显示的 6 位数字',
                    border: OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(codeController.text.trim()),
              child: const Text('确认绑定'),
            ),
          ],
        ),
      );
      if (code == null || !mounted) return;
      await _repo.submitTwoFactorCode(code, enable: true);
      if (!mounted) return;
      showQyToast(context, '两步验证已开启', success: true);
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        showQyToast(context, '绑定失败：${error.message}', success: false);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'security#enroll');
      if (mounted) {
        showQyToast(context, '绑定失败，请稍后重试', success: false);
      }
    } finally {
      codeController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 关闭两步验证：输入当前验证码 → disable。
  Future<void> _disable() async {
    if (_busy) return;
    final TextEditingController codeController = TextEditingController();
    try {
      final code = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('关闭两步验证'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('需要验证器当前显示的 6 位数字，防止他人擅自关闭。',
                  style: TextStyle(fontSize: 11.5, color: QyColors.muted)),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '6 位验证码',
                  border: OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(codeController.text.trim()),
              child: const Text('确认关闭'),
            ),
          ],
        ),
      );
      if (code == null || !mounted) return;
      setState(() => _busy = true);
      await _repo.submitTwoFactorCode(code, enable: false);
      if (!mounted) return;
      showQyToast(context, '两步验证已关闭', success: true);
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        showQyToast(context, '关闭失败：${error.message}', success: false);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'security#disable');
      if (mounted) {
        showQyToast(context, '关闭失败，请稍后重试', success: false);
      }
    } finally {
      codeController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDevices() async {
    await context.push<bool>(AppRouter.devices);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _twoFactor;
    final account = _account;
    return ColoredBox(
      color: QyColors.canvas,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: qyProtoScrollPhysics,
          padding: const EdgeInsets.only(bottom: 26),
          children: <Widget>[
            ProtoNav(
              title: '安全中心',
              subtitle: '后端 /api/security/2fa · /api/tokens',
              leading: ProtoIconButton(
                icon: Icons.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...<Widget>[
              _AccountCard(account: account),
              _TwoFactorCard(
                status: status,
                busy: _busy,
                onEnable: _startEnrollment,
                onDisable: _disable,
                onRetry: () {
                  _load();
                },
              ),
              const SizedBox(height: 14),
              _EntryCard(onDevices: _openDevices),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Text(
                  '开启两步验证后，下次登录需在登录页填写验证器显示的 6 位数字。'
                  '请务必先在验证器 App 中确认能生成正确验证码，再关闭本页面。',
                  style: TextStyle(fontSize: 11.5, color: QyColors.muted, height: 1.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({this.account});

  final AccountStatus? account;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.person_outline, size: 18, color: QyColors.primary),
              SizedBox(width: 8),
              Text('当前账号',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: QyColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a == null
                ? '账户信息加载中'
                : '${a.username} · ${a.isAdmin ? "管理员" : "普通用户"}\n'
                    '会员：${a.vipInfo.statusLabel}\n'
                    '存储账号：${a.storageConnected ? "已连接" : "未连接"}',
            style: const TextStyle(
                fontSize: 12, color: QyColors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _TwoFactorCard extends StatelessWidget {
  const _TwoFactorCard({
    required this.status,
    required this.busy,
    required this.onEnable,
    required this.onDisable,
    required this.onRetry,
  });

  final TwoFactorStatus? status;
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final enabled = s?.enabled ?? false;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                enabled ? Icons.verified_user : Icons.shield_outlined,
                size: 20,
                color: enabled ? QyColors.mintDeep : QyColors.amberDeep,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text('两步验证（TOTP）',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: QyColors.ink)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: enabled ? QyColors.mintSoft : QyColors.canvas,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(
                  s == null ? '加载失败' : s.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: enabled ? QyColors.mintDeep : QyColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            s == null
                ? '无法读取两步验证状态，请下拉刷新重试。'
                : enabled
                    ? '登录时除账号密码外，还需验证器生成的 6 位动态码。'
                    : '开启后，登录时需要额外输入验证器 App 的 6 位动态码。',
            style: const TextStyle(
                fontSize: 11.5, color: QyColors.muted, height: 1.5),
          ),
          if (s?.pendingSetup ?? false)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('存在未完成的绑定，继续绑定即可覆盖。',
                  style: TextStyle(fontSize: 11, color: QyColors.amberDeep)),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (enabled)
                TextButton(
                  onPressed: busy ? null : onDisable,
                  child: const Text('关闭',
                      style: TextStyle(fontSize: 11.5, color: QyColors.coral)),
                ),
              const SizedBox(width: 6),
              QyTapScale(
                onTap: busy || s == null
                    ? () {
                        if (s == null) onRetry();
                      }
                    : onEnable,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    gradient: LinearGradient(
                      begin: Alignment(-0.5, -0.87),
                      end: Alignment(0.5, 0.87),
                      colors: <Color>[Color(0xFF3C7CFF), QyColors.primary],
                    ),
                  ),
                  child: Text(
                    busy
                        ? '处理中…'
                        : (s == null
                            ? '重试'
                            : (enabled ? '重新绑定' : '开启验证')),
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: QyColors.onDark),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.onDevices});

  final VoidCallback onDevices;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: QyTapScale(
        onTap: onDevices,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: QyColors.amberSoft,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.devices,
                    size: 18, color: QyColors.amberDeep),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('登录设备管理',
                        style: TextStyle(fontSize: 13.5, color: QyColors.ink)),
                    SizedBox(height: 3),
                    Text('查看凭证、备注设备、吊销下线',
                        style:
                            TextStyle(fontSize: 11, color: QyColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: QyColors.chevron),
            ],
          ),
        ),
      ),
    );
  }
}
