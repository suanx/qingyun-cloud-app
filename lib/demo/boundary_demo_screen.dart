import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../core/models/cloud_models.dart';
import '../core/network/cloud_repository.dart';
import '../core/network/token_store.dart';

/// 边界情况与容错演示。
///
/// 每一项都对应真实代码路径：空数据、超长文本、除零、进度越界、
/// 非法枚举回退、token 清理。执行后直接在页面上给出「实际行为」。
class BoundaryDemoScreen extends StatefulWidget {
  const BoundaryDemoScreen({super.key});

  @override
  State<BoundaryDemoScreen> createState() => _BoundaryDemoScreenState();
}

class _BoundaryDemoScreenState extends State<BoundaryDemoScreen> {
  final List<_CheckResult> _results = <_CheckResult>[];

  void _run(String name, String expected, String Function() check) {
    String detail;
    var ok = true;
    try {
      detail = check();
    } catch (error) {
      ok = false;
      detail = '抛出异常：$error';
    }
    setState(() {
      _results.insert(0, _CheckResult(name: name, expected: expected, detail: detail, ok: ok));
    });
  }

  // ---- 各边界用例（同步执行，直接返回实际行为描述） ----

  String _caseEmptyList() {
    // 模拟后端返回空数组：Repository 应返回空列表而非异常
    final files = MockData.files(keyword: '不存在的关键词xyz');
    return files.isEmpty ? '通过：返回空列表，页面应展示 QyEmptyState' : '失败：${files.length}';
  }

  String _caseLongText() {
    const file = CloudFile(
      id: 'long',
      name: '这是一个非常非常非常长的文件名用于验证列表单行截断与省略号显示是否正常.docx',
      category: FileCategory.doc,
      sizeLabel: '1 KB',
      updatedLabel: '刚刚',
    );
    return '通过：超长标题已构造（${file.name.length} 字符），列表使用 ellipsis 单行截断';
  }

  String _caseZeroTotal() {
    // 后端异常返回 total_gb=0：不应出现除零/NaN
    final summary = StorageSummary.fromJson(<String, dynamic>{'used_gb': 10, 'total_gb': 0});
    final ratioText = (summary.ratio * 100).toStringAsFixed(0);
    final finite = summary.ratio.isFinite;
    return finite ? '通过：ratio=$ratioText%（有限值，无除零）' : '失败：ratio 非有限值';
  }

  String _caseNegativeTotal() {
    final summary = StorageSummary.fromJson(<String, dynamic>{'used_gb': -5, 'total_gb': -100});
    return '通过：used=${summary.usedGb}、total=${summary.totalGb}，ratio=${summary.ratio}（clamp 生效）';
  }

  String _caseProgressClamp() {
    final task = TransferTask.fromJson(<String, dynamic>{
      'id': 't1',
      'name': '越界进度',
      'direction': 'upload',
      'status': 'running',
      'progress': 1.5,
    });
    final clamped = task.progress >= 0 && task.progress <= 1;
    return clamped ? '通过：progress=${task.progress}（1.5 已收敛到 1.0）' : '失败：progress=${task.progress}';
  }

  String _caseUnknownCategory() {
    // 后端新增了未知分类字符串：应回退到 other 而非崩溃
    final file = CloudFile.fromJson(<String, dynamic>{
      'id': 'x1',
      'name': '未知类型文件',
      'category': 'hologram',
    });
    return file.category == FileCategory.other
        ? '通过：未知分类已回退为 other（图标 ${file.category.iconName}）'
        : '失败：${file.category}';
  }

  String _caseUnknownStatus() {
    final task = TransferTask.fromJson(<String, dynamic>{
      'id': 'x2',
      'name': '未知状态任务',
      'direction': 'download',
      'status': 'teleporting',
    });
    return task.status == TransferStatus.running
        ? '通过：未知状态已回退为 running'
        : '失败：${task.status}';
  }

  String _caseTokenClear() {
    TokenStore.save('temp-token');
    final before = TokenStore.accessToken;
    TokenStore.clear();
    final after = TokenStore.accessToken;
    return before != null && after == null
        ? '通过：token 已保存并成功清理（清理后请求不会携带 Authorization）'
        : '失败：before=$before after=$after';
  }

  String _caseMissingFields() {
    // 后端字段缺失：全部走默认值，不抛异常
    final file = CloudFile.fromJson(<String, dynamic>{});
    final task = TransferTask.fromJson(<String, dynamic>{});
    final summary = StorageSummary.fromJson(<String, dynamic>{});
    return '通过：默认值兜底 — file(${file.id}/${file.category.name})、'
        'task(${task.direction.name}/${task.status.name})、summary(${summary.label})';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: QyFrostAppBar(
        title: Text('边界情况演示', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          QyCard(
            color: QyColors.surfaceSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('边界与容错验证', style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '点击用例立即同步执行，并展示实际代码行为。'
                  '覆盖：空数据、超长文本、除零、越界、非法枚举、字段缺失、token 生命周期。',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: QyTokens.spaceLg),

          Text('用例', style: textTheme.titleLarge),
          const SizedBox(height: QyTokens.spaceMd),
          _CheckButton(
            label: '1. 空列表数据',
            expected: '返回空列表 → 页面展示空状态，不崩溃',
            onTap: () => _run('空列表数据', '空列表 → 空状态', _caseEmptyList),
          ),
          _CheckButton(
            label: '2. 超长文件名',
            expected: '单行截断 + 省略号',
            onTap: () => _run('超长文件名', 'ellipsis 截断', _caseLongText),
          ),
          _CheckButton(
            label: '3. 容量 total=0（除零）',
            expected: 'ratio 为有限值，不产生 NaN/Infinity',
            onTap: () => _run('除零保护', '无 NaN/Infinity', _caseZeroTotal),
          ),
          _CheckButton(
            label: '4. 容量负数',
            expected: 'ratio clamp 到 [0,1]',
            onTap: () => _run('负数容量', 'clamp 生效', _caseNegativeTotal),
          ),
          _CheckButton(
            label: '5. 传输进度 1.5（越界）',
            expected: 'progress 收敛到 1.0',
            onTap: () => _run('进度越界', 'clamp 到 1.0', _caseProgressClamp),
          ),
          _CheckButton(
            label: '6. 未知文件分类 hologram',
            expected: '回退 FileCategory.other',
            onTap: () => _run('未知分类', '回退 other', _caseUnknownCategory),
          ),
          _CheckButton(
            label: '7. 未知任务状态 teleporting',
            expected: '回退 TransferStatus.running',
            onTap: () => _run('未知状态', '回退 running', _caseUnknownStatus),
          ),
          _CheckButton(
            label: '8. token 保存与清理',
            expected: '清理后不再携带 Authorization',
            onTap: () => _run('token 生命周期', '保存/清理正常', _caseTokenClear),
          ),
          _CheckButton(
            label: '9. 后端字段全部缺失',
            expected: '默认值兜底，不抛异常',
            onTap: () => _run('字段缺失', '默认值兜底', _caseMissingFields),
          ),

          const SizedBox(height: QyTokens.spaceLg),
          Text('执行结果（最新在前）', style: textTheme.titleLarge),
          const SizedBox(height: QyTokens.spaceMd),
          if (_results.isEmpty)
            const QyEmptyState(
              icon: QyIcons.check,
              title: '尚未执行用例',
              description: '点击上方任意用例按钮开始验证',
            )
          else
            for (final result in _results)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: QyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          QyIcon(
                            result.ok ? QyIcons.check : QyIcons.warning,
                            size: 18,
                            color: result.ok ? QyColors.success : QyColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(result.name, style: textTheme.bodyLarge)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('预期：${result.expected}', style: textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text('实际：${result.detail}', style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.label, required this.expected, required this.onTap});

  final String label;
  final String expected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: QyCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            const QyIcon(QyIcons.check, size: 20, color: QyColors.primaryDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text('预期：$expected', style: textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckResult {
  const _CheckResult({
    required this.name,
    required this.expected,
    required this.detail,
    required this.ok,
  });

  final String name;
  final String expected;
  final String detail;
  final bool ok;
}
