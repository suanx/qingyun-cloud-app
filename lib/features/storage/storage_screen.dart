import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';
import '../../core/config/admin_gate.dart';

/// 06 存储空间（对齐 screen-storage）。占比来自 lanflare 容量概览。
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final CloudRepository _repo = CloudRepository();
  StorageSummary? _summary;
  StorageAnalysis? _analysis;
  bool _analyzing = true;
  bool _cleaning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await _repo.storageSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'storage_screen#1');
      // 加载失败时保持占位展示。
    }
    await _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    if (mounted) setState(() => _analyzing = true);
    try {
      final analysis = await _repo.storageAnalysis();
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _analyzing = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'storage_screen#analysis');
      if (!mounted) return;
      setState(() {
        _analysis = null;
        _analyzing = false;
      });
    }
  }

  /// 「管理」：展示管理员全局账号池的真实状态。
  ///
  /// 账号由管理员在网页端统一配置，App 不提供绑定 / 解绑入口；这里只读取
  /// `GET /api/status` 的 storage_pool 概览，不编造任何数值。
  Future<void> _openAccount() async {
    try {
      final status = await _repo.accountStatus();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('存储账号池'),
          content: Text(
            '账号总数：${status.poolAccounts}\n'
            '自动上传池：${status.autoAccounts} 个蓝奏账号\n'
            '均衡模式：${status.balanceModeLabel}\n'
            '当前生效：${status.effectiveModeLabel}\n\n'
            '${status.legacyFallback ? '当前为旧绑定兼容模式，请管理员在网页端配置账号池。' : '账号由管理员在网页端统一管理，App 不提供绑定入口。'}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (_) {
      // 状态读取失败不阻断页面；不显示假数据。
    }
    if (mounted) await _load();
  }

  /// 「查看会员」：admin 直达会员管理页，普通用户展示真实会员状态。
  /// 不接支付渠道。
  Future<void> _openMembership() async {
    try {
      final status = await _repo.accountStatus();
      if (!mounted) return;
      if (status.isAdmin) {
        await context.push<bool>(AppRouter.adminVip);
        await _load();
      } else {
        showQyToast(context, status.vipSubtitle);
      }
    } on ApiException catch (error) {
      if (mounted) showQyToast(context, error.message, success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'storage_screen#membership');
      if (mounted) {
        showQyToast(context, '账户状态获取失败', success: false);
      }
    }
  }

  Future<void> _clean() async {
    final ids = _analysis?.allItemIds ?? const <int>[];
    if (ids.isEmpty || _cleaning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('清理这些项目？'),
        content: Text(
          '共 ${ids.length} 项，预计释放 '
          '${CloudRepository.humanSize(_analysis?.totalReclaimableBytes ?? 0)}。\n'
          '文件会移入回收站，可随时恢复。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cleaning = true);
    try {
      final result = await _repo.cleanStorage(ids);
      if (!mounted) return;
      showQyToast(
        context,
        '已清理 ${result.count} 项，释放 '
        '${CloudRepository.humanSize(result.freedBytes)}',
        success: true,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) showQyToast(context, error.message, success: false);
      // 建议集合已变化（409 等）时刷新，避免用户对着过期数据反复点。
      await _loadAnalysis();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'storage_screen#clean');
      if (mounted) {
        showQyToast(context, '清理失败，请稍后重试', success: false);
      }
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        physics: qyProtoScrollPhysics,
        padding: const EdgeInsets.only(bottom: 26),
        children: <Widget>[
          ProtoNav(
            title: '存储空间',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(QyRoutes.profile);
                }
              },
            ),
            actions: <Widget>[
              QyTapScale(
                onTap: _openAccount,
                child: const Text('管理', style: ProtoText.sectionMore),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Donut(summary: _summary),
          _LegendGrid(byCategory: _summary?.byCategory),
          _CleanCard(
            analysis: _analysis,
            analyzing: _analyzing,
            cleaning: _cleaning,
            onClean: _clean,
          ),
          _UpgradeCard(onTap: _openMembership),
          const ProtoFootNote('空间每 5 分钟同步一次',
              padding: EdgeInsets.fromLTRB(0, 4, 0, 10)),
        ],
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({this.summary});

  final StorageSummary? summary;

  @override
  Widget build(BuildContext context) {
    final clamped = (summary?.ratio ?? 0).clamp(0.0, 1.0);
    final label = summary == null
        ? '— / — GB'
        : '${summary!.usedGb.toStringAsFixed(1)} / ${summary!.totalGb.toStringAsFixed(0)} GB';
    return Center(
      child: SizedBox(
        width: 172,
        height: 172,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.rotate(
              angle: -math.pi / 2,
              child: Container(
                width: 172,
                height: 172,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    stops: <double>[0, clamped, clamped, 1],
                    colors: const <Color>[
                      Color(0xFF4C8DFF),
                      Color(0xFF4C8DFF),
                      Color(0xFFE9EEF7),
                      Color(0xFFE9EEF7),
                    ],
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x661F4899), blurRadius: 34, offset: Offset(0, 16), spreadRadius: -18),
                  ],
                ),
              ),
            ),
            Container(
              width: 124,
              height: 124,
              decoration: const BoxDecoration(color: QyColors.surface, shape: BoxShape.circle),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -1, color: QyColors.ink),
                    children: <TextSpan>[
                      TextSpan(text: '${(clamped * 100).round()}'),
                      const TextSpan(
                        text: '%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: QyColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(label, style: ProtoText.label105),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendGrid extends StatelessWidget {
  const _LegendGrid({this.byCategory});

  final StorageCategoryStats? byCategory;

  static const double _gb = 1024 * 1024 * 1024;

  String _gbText(int bytes) => (bytes / _gb).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final StorageCategoryStats stats = byCategory ?? const StorageCategoryStats();
    final String image = _gbText(stats.image);
    final String video = _gbText(stats.video);
    final String doc = _gbText(stats.doc);
    final String other =
        _gbText(stats.music + stats.archive);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _LegendItem(
                color: const Color(0xFF4C8DFF),
                name: '照片',
                value: image,
                onTap: () => showQyToast(context, '照片：$image GB'),
              ),
              const SizedBox(width: 10),
              _LegendItem(
                color: QyColors.mint,
                name: '视频',
                value: video,
                onTap: () => showQyToast(context, '视频：$video GB'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _LegendItem(
                color: QyColors.amber,
                name: '文档',
                value: doc,
                onTap: () => showQyToast(context, '文档：$doc GB'),
              ),
              const SizedBox(width: 10),
              _LegendItem(
                color: const Color(0xFFA78BFF),
                name: '音乐/压缩包',
                value: other,
                onTap: () => showQyToast(context, '音乐/压缩包：$other GB'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.name,
    required this.value,
    required this.onTap,
  });

  final Color color;
  final String name;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: QyTapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: const BoxDecoration(
            color: QyColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(name, style: const TextStyle(fontSize: 11.5, color: QyColors.sub)),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: QyColors.ink),
                  children: <TextSpan>[
                    TextSpan(text: value),
                    const TextSpan(
                      text: 'GB',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: QyColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CleanCard extends StatelessWidget {
  const _CleanCard({
    required this.analysis,
    required this.analyzing,
    required this.cleaning,
    required this.onClean,
  });

  final StorageAnalysis? analysis;
  final bool analyzing;
  final bool cleaning;
  final Future<void> Function() onClean;

  String _rowLabel(String fallback, String key, StorageAnalysis? data) {
    final group = data?.group(key);
    if (group == null || group.count <= 0) return fallback;
    return '${group.label} · ${group.count} 项';
  }

  String _rowSize(String key, StorageAnalysis? data) {
    final group = data?.group(key);
    if (group == null || group.count <= 0 || group.sizeBytes <= 0) return '—';
    return CloudRepository.humanSize(group.sizeBytes);
  }

  @override
  Widget build(BuildContext context) {
    final data = analysis;
    final ids = data?.allItemIds ?? const <int>[];
    final canClean = !cleaning && !analyzing && ids.isNotEmpty;
    final title = analyzing
        ? '正在分析空间…'
        : (data == null || data.isEmpty)
            ? '暂无清理建议'
            : '为你找到 ${CloudRepository.humanSize(data.totalReclaimableBytes)} 可清理';
    final buttonLabel =
        cleaning ? '清理中…' : (ids.isEmpty ? '暂无可清理项' : '一键清理');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: QyColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color(0xFFEDF3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome, size: 19, color: QyColors.mint),
              const SizedBox(width: 9),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: QyColors.ink)),
              ),
              const Text('智能整理', style: ProtoText.label105),
            ],
          ),
          const SizedBox(height: 12),
          _CleanRow(
            label: _rowLabel('重复文件', 'duplicate', data),
            size: _rowSize('duplicate', data),
          ),
          _CleanRow(
            label: _rowLabel('大文件', 'large', data),
            size: _rowSize('large', data),
          ),
          _CleanRow(
            label: _rowLabel('空文件夹', 'empty_dir', data),
            size: _rowSize('empty_dir', data),
          ),
          const SizedBox(height: 10),
          // 清理是写操作：普通用户不渲染按钮，也不留「点了没反应」的假入口。
          AdminOnly(
            fallback: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '清理建议仅管理员可执行',
                style: TextStyle(fontSize: 12.5, color: QyColors.muted),
              ),
            ),
            child: QyTapScale(
              onTap: canClean ? () { onClean(); } : () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment(-0.5, -0.87),
                    end: Alignment(0.5, 0.87),
                    colors: <Color>[Color(0xFF3C7CFF), QyColors.primary],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Color(0xB32F6BFF), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -8),
                  ],
                ),
                child: Center(
                  child: Text(buttonLabel,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: QyColors.onDark)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanRow extends StatelessWidget {
  const _CleanRow({required this.label, required this.size});

  final String label;
  final String size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: QyColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475467))),
          const Spacer(),
          Text(size, style: const TextStyle(fontSize: 11.5, color: QyColors.muted)),
        ],
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(QyTokens.radiusLg)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.workspace_premium, size: 19, color: QyColors.amber),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('会员服务',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QyColors.ink)),
                SizedBox(height: 3),
                Text('查看会员状态与权益', style: ProtoText.label105),
              ],
            ),
          ),
          QyTapScale(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment(-0.7, -0.7),
                  end: Alignment(0.7, 0.7),
                  colors: <Color>[Color(0xFF3C7CFF), Color(0xFF6FA8FF)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0x472F6BFF), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: const Text('查看会员',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: QyColors.onDark)),
            ),
          ),
        ],
      ),
    );
  }
}
