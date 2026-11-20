import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';

/// 帮助与反馈：真实 FAQ + 反馈提交 / 查看 / 管理员回复闭环。
///
/// FAQ 描述的是本项目已落地的真实行为，不含演示数据；反馈落库到 lanflare
/// `feedback` 表（VPS 上随 SQLite 持久化），用户只能看自己的，管理员可回复。
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _Faq {
  const _Faq(this.question, this.answer);

  final String question;
  final String answer;
}

const List<_Faq> _faqs = <_Faq>[
  _Faq(
    '上传或下载提示「请先绑定存储账号」',
    'App 登录账号和蓝奏云存储账号是两个账号。到「存储空间 → 管理」绑定存储账号后，'
        '上传、下载、删除、清理才会真正生效。绑定状态与连通性都在该页实时检测。',
  ),
  _Faq(
    '登录时要求输入 6 位验证码',
    '说明你在「安全中心」开启了两步验证，用验证器里的动态码登录即可。'
        '「设备管理」里可以吊销不再使用的登录令牌，吊销后对应设备立即失效。',
  ),
  _Faq(
    '删除的文件还能找回吗',
    '删除是「移入回收站」，在回收站页可以恢复。只有手动清空回收站或彻底删除才会'
        '移除云端文件；服务端没有自动过期删除，请自行定期整理。',
  ),
  _Faq(
    '大文件上传会失败吗',
    '超过 90MB 的文件由 App 自动按 8MB 分块串行上传，最后一格完成后入库。'
        '自建 VPS 需保证服务端临时目录可写，切块期间请勿退出页面。',
  ),
  _Faq(
    '换绑了另一个存储账号，旧文件呢',
    '旧的文件记录仍指向原来的存储账号，不会自动迁移。绑定页会显示真实的活跃文件数，'
        '并在重新绑定时明确提示这一点。',
  ),
  _Faq(
    '怎么连接自己部署的服务',
    '在「设置 → 服务地址」填完整域名并保存，先用「测试连接」确认返回的是 lanflare，'
        '再退出登录重新登录新服务。原服务的凭证在新服务上不可用。',
  ),
  _Faq(
    '提交反馈后谁会看到',
    '反馈保存在服务端数据库，你本人和管理员可见；管理员可回复或标记状态，'
        '回复会显示在下方「我的反馈」里。',
  ),
];

class _HelpScreenState extends State<HelpScreen> {
  final CloudRepository _repo = CloudRepository();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  FeedbackCategory _category = FeedbackCategory.bug;
  bool _loading = true;
  bool _submitting = false;
  bool _busy = false;
  bool _isAdmin = false;
  String? _error;
  List<FeedbackItem> _myItems = <FeedbackItem>[];
  List<FeedbackItem> _adminItems = <FeedbackItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<FeedbackItem> mine = await _repo.myFeedback();
      if (!mounted) return;
      setState(() => _myItems = mine);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'help#myFeedback');
      if (mounted) {
        setState(() => _error = '反馈列表加载失败：$error');
      }
    }
    try {
      final AccountStatus status = await _repo.accountStatus();
      if (!mounted) return;
      setState(() => _isAdmin = status.isAdmin);
      if (status.isAdmin) {
        final List<FeedbackItem> all = await _repo.adminFeedback();
        if (!mounted) return;
        setState(() => _adminItems = all);
      } else {
        setState(() => _adminItems = <FeedbackItem>[]);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'help#account');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final String content = _contentController.text.trim();
    if (content.length < 5) {
      showQyToast(context, '请至少填写 5 个字，方便我们定位问题', success: false);
      return;
    }
    if (content.length > 2000) {
      showQyToast(context, '反馈内容最多 2000 字', success: false);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _repo.submitFeedback(
        category: _category,
        content: content,
        contact: _contactController.text.trim(),
      );
      if (!mounted) return;
      _contentController.clear();
      _contactController.clear();
      showQyToast(context, '反馈已提交', success: true);
      setState(() => _submitting = false);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showQyToast(context, '提交失败：${error.message}', success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'help#submit');
      if (!mounted) return;
      setState(() => _submitting = false);
      showQyToast(context, '提交失败，请稍后重试', success: false);
    }
  }

  Future<void> _openReplyDialog(FeedbackItem item) async {
    if (_busy) return;
    final _ReplyResult? result = await showDialog<_ReplyResult>(
      context: context,
      builder: (BuildContext ctx) => _ReplyDialog(item: item),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.replyFeedback(
        item.id,
        status: result.status,
        reply: result.reply,
      );
      if (!mounted) return;
      showQyToast(context, '回复已保存', success: true);
      setState(() => _busy = false);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showQyToast(context, '保存失败：${error.message}', success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'help#reply');
      if (!mounted) return;
      setState(() => _busy = false);
      showQyToast(context, '保存失败，请稍后重试', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: qyProtoScrollPhysics,
          padding: const EdgeInsets.only(bottom: 30),
          children: <Widget>[
            ProtoNav(
              title: '帮助与反馈',
              subtitle: '常见问题 · 真实反馈',
              leading: ProtoIconButton(
                icon: Icons.arrow_back,
                onTap: () => context.pop(),
              ),
              actions: <Widget>[
                ProtoIconButton(
                  icon: Icons.refresh,
                  onTap: () => _load(),
                ),
              ],
            ),
            const _SectionTitle('常见问题'),
            _Card(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < _faqs.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    _FaqTile(faq: _faqs[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('提交反馈'),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text('告诉我们遇到的问题或想要的功能，内容会保存到服务端。',
                      style: TextStyle(fontSize: 11, color: QyColors.muted)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FeedbackCategory>(
                    value: _category,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<FeedbackCategory>>[
                      for (final FeedbackCategory c in FeedbackCategory.values)
                        DropdownMenuItem<FeedbackCategory>(
                          value: c,
                          child: Text(c.label,
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                    ],
                    onChanged: (FeedbackCategory? value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    maxLines: 5,
                    minLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: '问题描述',
                      hintText: '请尽量描述操作步骤与看到的提示',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12.5, color: QyColors.ink),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contactController,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: '联系方式（选填）',
                      hintText: '邮箱 / 其它联系方式，便于回复',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12.5, color: QyColors.ink),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : () => _submit(),
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: Text(_submitting ? '提交中…' : '提交反馈'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('我的反馈'),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: QyTapScale(
                  onTap: () => _load(),
                  child: Text('$_error，点击重试',
                      style: const TextStyle(
                          fontSize: 11.5, color: QyColors.coral)),
                ),
              )
            else if (_myItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text('还没有反馈记录',
                      style: TextStyle(fontSize: 11.5, color: QyColors.muted)),
                ),
              )
            else
              _Card(
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < _myItems.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1),
                      _FeedbackTile(item: _myItems[i]),
                    ],
                  ],
                ),
              ),
            if (_isAdmin) ...<Widget>[
              const SizedBox(height: 16),
              const _SectionTitle('反馈管理（仅管理员）'),
              if (_adminItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text('暂无收到的反馈',
                        style: TextStyle(fontSize: 11.5, color: QyColors.muted)),
                  ),
                )
              else
                _Card(
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < _adminItems.length; i++) ...<Widget>[
                        if (i > 0) const Divider(height: 1),
                        _FeedbackTile(
                          item: _adminItems[i],
                          showAuthor: true,
                          busy: _busy,
                          onTap: () => _openReplyDialog(_adminItems[i]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            const ProtoFootNote(
              '反馈保存在你部署的服务端，不经过第三方',
              padding: EdgeInsets.fromLTRB(0, 20, 0, 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyResult {
  const _ReplyResult({required this.status, required this.reply});

  final FeedbackStatus status;
  final String reply;
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({required this.item});

  final FeedbackItem item;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late FeedbackStatus _status;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _status = widget.item.status == FeedbackStatus.open
        ? FeedbackStatus.replied
        : widget.item.status;
    _controller = TextEditingController(text: widget.item.adminReply);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('回复反馈'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${widget.item.category.label} · '
              '${widget.item.username ?? '#${widget.item.uid}'} · '
              '${widget.item.createdLabel}',
              style: const TextStyle(fontSize: 11, color: QyColors.muted),
            ),
            const SizedBox(height: 8),
            Text(widget.item.content,
                style: const TextStyle(fontSize: 12, color: QyColors.ink)),
            const SizedBox(height: 12),
            DropdownButton<FeedbackStatus>(
              value: _status,
              isExpanded: true,
              items: <DropdownMenuItem<FeedbackStatus>>[
                for (final FeedbackStatus s in FeedbackStatus.values)
                  DropdownMenuItem<FeedbackStatus>(
                    value: s,
                    child: Text(s.label,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
              ],
              onChanged: (FeedbackStatus? value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 2,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: '回复内容',
                hintText: '填写回复；清空并保存可撤回回复',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12.5, color: QyColors.ink),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _ReplyResult(
              status: _status,
              reply: _controller.text.trim(),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: QyColors.heroLabel),
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
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: child,
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        iconColor: QyColors.primary,
        collapsedIconColor: QyColors.hint,
        title: Text(
          faq.question,
          style: const TextStyle(fontSize: 12.5, color: QyColors.ink),
        ),
        children: <Widget>[
          Text(
            faq.answer,
            style: const TextStyle(
                fontSize: 11.5, height: 1.5, color: QyColors.muted),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({
    required this.item,
    this.showAuthor = false,
    this.busy = false,
    this.onTap,
  });

  final FeedbackItem item;
  final bool showAuthor;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(item.category.icon, size: 15, color: QyColors.primary),
              const SizedBox(width: 6),
              Text(item.category.label,
                  style: const TextStyle(fontSize: 11, color: QyColors.muted)),
              const Spacer(),
              _StatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: 7),
          Text(item.content,
              style: const TextStyle(fontSize: 12.5, color: QyColors.ink)),
          const SizedBox(height: 6),
          Text(
            '提交于 ${item.createdLabel}'
            '${showAuthor ? ' · ${item.username ?? '#${item.uid}'}' : ''}'
            '${item.contact.isNotEmpty ? ' · 联系方式：${item.contact}' : ''}',
            style: const TextStyle(fontSize: 10.5, color: QyColors.hint),
          ),
          if (item.adminReply.isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: QyColors.mintSoft,
                borderRadius: const BorderRadius.all(Radius.circular(9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '管理员回复${item.repliedLabel.isEmpty ? '' : ' · ${item.repliedLabel}'}',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: QyColors.mintDeep),
                  ),
                  const SizedBox(height: 4),
                  Text(item.adminReply,
                      style:
                          const TextStyle(fontSize: 11.5, color: QyColors.ink)),
                ],
              ),
            ),
          ],
          if (onTap != null) ...<Widget>[
            const SizedBox(height: 7),
            Text(
              busy ? '处理中…' : '回复 / 修改状态 ›',
              style: const TextStyle(fontSize: 11, color: QyColors.primary),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return QyTapScale(onTap: busy ? () {} : onTap!, child: content);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final FeedbackStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      FeedbackStatus.open => QyColors.amberDeep,
      FeedbackStatus.replied => QyColors.mintDeep,
      FeedbackStatus.closed => QyColors.hint,
    };
    final Color background = switch (status) {
      FeedbackStatus.open => QyColors.amberSoft,
      FeedbackStatus.replied => QyColors.mintSoft,
      FeedbackStatus.closed => QyColors.track,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
