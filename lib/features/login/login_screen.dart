import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';
import '../../core/config/admin_gate.dart';

/// 登录页：lanflare 账号密码登录（`POST /api/auth/login`）。
///
/// - 支持可选的两步验证码（lanflare 开启 TOTP 时填写）。
/// - 成功后换取可吊销的 `lf_` API 令牌存入 TokenStore，
///   之后请求自动携带 `Authorization: Bearer`；令牌换发失败时降级为会话 Cookie。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _account = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _totp = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _totpFocus = FocusNode();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    _totp.dispose();
    _passwordFocus.dispose();
    _totpFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final account = _account.text.trim();
    final password = _password.text;
    if (account.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入账号和密码');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final username = await CloudRepository()
          .login(account, password, totpCode: _totp.text.trim());
      if (!mounted) return;
      await AdminGate.instance.refresh();
    showQyToast(context, '欢迎回来，$username');
      context.go(QyRoutes.home);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      // 后端开启 TOTP 后返回 401「需要两步验证码」：直接把焦点送到验证码框，
      // 用户不用再手动点一次，避免「开了 2FA 就登不进来」的体验断点。
      if (error.message.contains('验证码') || error.message.contains('两步')) {
        _totpFocus.requestFocus();
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'login_screen#1');
      if (!mounted) return;
      setState(() => _error = '登录失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QyColors.canvas,
      body: SafeArea(
        child: ListView(
          physics: qyProtoScrollPhysics,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: <Widget>[
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF4C8DFF), Color(0xFF7FB6FF)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x334C8DFF),
                    offset: Offset(0, 10),
                    blurRadius: 24,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: const Icon(Icons.cloud_outlined, size: 34, color: QyColors.onDark),
            ),
            const SizedBox(height: 18),
            Text('欢迎回来', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('登录 lanflare 账号，你的文件随时在云上',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 28),
            QyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Field(
                    controller: _account,
                    icon: Icons.person_outline,
                    hint: '用户名或邮箱',
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const Divider(color: QyColors.divider, height: 1),
                  _Field(
                    controller: _password,
                    icon: Icons.lock_outline,
                    hint: '登录密码',
                    obscure: _obscure,
                    focusNode: _passwordFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: QyColors.muted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const Divider(color: QyColors.divider, height: 1),
                  _Field(
                    controller: _totp,
                    icon: Icons.shield_outlined,
                    hint: '开启两步验证后填写 6 位验证码',
                    focusNode: _totpFocus,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.error_outline, size: 16, color: QyColors.coral),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(fontSize: 12.5, color: QyColors.coral),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  QyButton(
                    _submitting ? '登录中…' : '登 录',
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const ProtoFootNote(
              '没有账号？在 lanflare 网页端注册后使用同一账号登录',
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
    this.keyboardType,
    this.maxLength,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 24, color: QyColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              maxLength: maxLength,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 14.5, color: QyColors.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13.5, color: QyColors.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                counterText: '',
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}
