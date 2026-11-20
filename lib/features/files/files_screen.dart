import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/utils/error_reporter.dart';
import '../../core/utils/upload_helper.dart';
import '../../widgets/proto_widgets.dart';
import '../../core/config/admin_gate.dart';

/// 02 全部文件（对齐 screen-files）。
///
/// - 列表走 lanflare `GET /api/list?pid=&sort=`，排序由后端真实 SQL 完成。
/// - 右上「排序」「更多」、文件/文件夹行尾菜单都是真实操作：
///   重命名、移动到（`/api/folders`）、删除到回收站、批量管理、查看详情。
/// - 分类胶囊是前端扩展名过滤，目录始终单独成组。
/// 全页无任何未接通的占位交互。
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

/// 目录钻取的返回栈：进入子目录前记录「父 pid + 父名称」。
class _TrailEntry {
  const _TrailEntry(this.pid, this.name);

  final int pid;
  final String name;
}

class _FilesScreenState extends State<FilesScreen> {
  final CloudRepository _repo = CloudRepository();

  int _chip = 0;
  int _pid = 0;
  String _folderName = '我的云盘';
  final List<_TrailEntry> _trail = <_TrailEntry>[];

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<CloudFile> _files = <CloudFile>[];
  List<CloudFile> _folders = <CloudFile>[];
  FileSort _sort = FileSort.timeDesc;

  bool _selectionMode = false;
  final Set<String> _selected = <String>{};

  static const List<String> _chips = <String>['全部', '文档', '图片', '视频', '音频'];
  static const List<FileCategory> _categories = <FileCategory>[
    FileCategory.all,
    FileCategory.doc,
    FileCategory.image,
    FileCategory.video,
    FileCategory.music,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nodes = await _repo.files(
        category: _categories[_chip],
        pid: _pid,
        includeDirs: true,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _folders = nodes.where((CloudFile n) => n.isDir).toList();
        _files = nodes.where((CloudFile n) => !n.isDir).toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'files_screen#1');
      if (!mounted) return;
      setState(() {
        _error = '加载失败，请检查网络后重试';
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 排序（后端 /api/list?sort=）
  // ---------------------------------------------------------------------------

  Future<void> _showSortSheet() async {
    final FileSort? picked = await showModalBottomSheet<FileSort>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('排序方式',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: QyColors.ink)),
              ),
            ),
            for (final FileSort option in FileSort.values)
              ListTile(
                dense: true,
                leading: Icon(
                  option == _sort ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 19,
                  color: option == _sort ? QyColors.primary : QyColors.hint,
                ),
                title: Text(option.label,
                    style: const TextStyle(fontSize: 13.5, color: QyColors.ink)),
                subtitle: Text(option.description,
                    style: const TextStyle(fontSize: 11, color: QyColors.muted)),
                onTap: () => Navigator.of(ctx).pop(option),
              ),
            const SizedBox(height: 8),
          ],
          ),
        ),
      ),
    );
    if (picked == null || picked == _sort) return;
    setState(() => _sort = picked);
    await _load();
  }

  // ---------------------------------------------------------------------------
  // 右上「更多操作」
  // ---------------------------------------------------------------------------

  Future<void> _showMoreSheet() async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('更多操作',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: QyColors.ink)),
              ),
            ),
            if (AdminGate.instance.isAdmin)
              ListTile(
                dense: true,
                leading: const Icon(Icons.checklist, size: 20, color: QyColors.primary),
                title: const Text('批量管理', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text('多选后批量删除或移动',
                    style: TextStyle(fontSize: 11, color: QyColors.muted)),
                onTap: () => Navigator.of(ctx).pop('select'),
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.sort, size: 20, color: QyColors.primary),
              title: Text('排序方式 · ${_sort.label}',
                  style: const TextStyle(fontSize: 13.5)),
              onTap: () => Navigator.of(ctx).pop('sort'),
            ),
            if (AdminGate.instance.isAdmin)
              ListTile(
                dense: true,
                leading: const Icon(Icons.create_new_folder, size: 20, color: QyColors.primary),
                title: const Text('新建文件夹', style: TextStyle(fontSize: 13.5)),
                onTap: () => Navigator.of(ctx).pop('mkdir'),
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.refresh, size: 20, color: QyColors.primary),
              title: const Text('刷新列表', style: TextStyle(fontSize: 13.5)),
              onTap: () => Navigator.of(ctx).pop('refresh'),
            ),
            if (_pid != 0) ...<Widget>[
              ListTile(
                dense: true,
                leading: const Icon(Icons.arrow_upward, size: 20, color: QyColors.primary),
                title: const Text('返回上一级', style: TextStyle(fontSize: 13.5)),
                onTap: () => Navigator.of(ctx).pop('up'),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.home_outlined, size: 20, color: QyColors.primary),
                title: const Text('回到根目录', style: TextStyle(fontSize: 13.5)),
                onTap: () => Navigator.of(ctx).pop('root'),
              ),
            ],
            const SizedBox(height: 8),
          ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'select') {
      setState(() {
        _selectionMode = true;
        _selected.clear();
      });
    } else if (action == 'sort') {
      await _showSortSheet();
    } else if (action == 'mkdir') {
      await _createFolder();
    } else if (action == 'refresh') {
      await _load();
    } else if (action == 'up') {
      _goUp();
    } else if (action == 'root') {
      _backToRoot();
    }
  }

  // ---------------------------------------------------------------------------
  // 目录钻取
  // ---------------------------------------------------------------------------

  void _openFolder(CloudFile folder) {
    final int? id = int.tryParse(folder.id);
    if (id == null || id <= 0) return;
    _trail.add(_TrailEntry(_pid, _folderName));
    setState(() {
      _pid = id;
      _folderName = folder.name;
    });
    _load();
  }

  void _goUp() {
    if (_trail.isEmpty) return;
    final _TrailEntry entry = _trail.removeLast();
    setState(() {
      _pid = entry.pid;
      _folderName = entry.name;
    });
    _exitSelection();
    _load();
  }

  void _backToRoot() {
    _trail.clear();
    setState(() {
      _pid = 0;
      _folderName = '我的云盘';
    });
    _exitSelection();
    _load();
  }

  // ---------------------------------------------------------------------------
  // 批量选择
  // ---------------------------------------------------------------------------

  void _exitSelection() {
    if (!_selectionMode) return;
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggleSelected(String id) {
    if (!_selectionMode) return;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final List<String> all = <String>[
      ..._folders.map((CloudFile f) => f.id),
      ..._files.map((CloudFile f) => f.id),
    ];
    final bool allSelected = all.isNotEmpty && all.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(all);
      }
    });
  }

  List<String> _selectedIds() => _selected.toList(growable: false);

  // ---------------------------------------------------------------------------
  // 通用真实操作：重命名 / 移动 / 删除 / 详情
  // ---------------------------------------------------------------------------

  Future<void> _rename(CloudFile file) async {
    if (_busy) return;
    final TextEditingController controller =
        TextEditingController(text: file.name);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(file.isDir ? '重命名文件夹' : '重命名文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: '新名称',
            helperText: '不能包含 / 或 \\',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    final String clean = name?.trim() ?? '';
    if (clean.isEmpty || !mounted) return;
    if (clean.contains('/') || clean.contains('\\')) {
      showQyToast(context, '名称不能包含路径分隔符', success: false);
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.renameFile(file.id, clean);
      if (!mounted) return;
      showQyToast(context, '已重命名为「$clean」', success: true);
      await _load();
    } on ApiException catch (error) {
      if (mounted) showQyToast(context, '重命名失败：${error.message}', success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'files_screen#rename');
      if (mounted) showQyToast(context, '重命名失败，请稍后重试', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 计算「不能作为移动目标」的目录集合：被选中的目录自身 + 其所有子孙。
  /// 后端 `moveNodes` 也有防环检查，这里是前端提前禁用，避免用户白选。
  Set<int> _blockedFolderIds(
    List<FolderEntry> folders,
    List<String> ids,
  ) {
    final Set<int> folderIds = folders.map((FolderEntry f) => f.id).toSet();
    final Set<int> movingDirs = ids
        .map(int.tryParse)
        .whereType<int>()
        .where((int id) => folderIds.contains(id))
        .toSet();
    final Set<int> blocked = <int>{...movingDirs};
    final List<int> queue = <int>[...movingDirs];
    while (queue.isNotEmpty) {
      final int current = queue.removeAt(0);
      for (final FolderEntry folder in folders) {
        if (folder.pid == current && blocked.add(folder.id)) {
          queue.add(folder.id);
        }
      }
    }
    return blocked;
  }

  Future<void> _moveIds(List<String> ids) async {
    if (ids.isEmpty || _busy) return;
    setState(() => _busy = true);
    List<FolderEntry> folders;
    try {
      folders = await _repo.listFolders();
    } on ApiException catch (error) {
      if (mounted) {
        showQyToast(context, '目录列表获取失败：${error.message}', success: false);
      }
      if (mounted) setState(() => _busy = false);
      return;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'files_screen#folders');
      if (mounted) showQyToast(context, '目录列表获取失败', success: false);
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    final Set<int> blocked = _blockedFolderIds(folders, ids);
    final int? target = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => _MovePickerDialog(
        folders: folders,
        blocked: blocked,
        currentPid: _pid,
      ),
    );
    if (target == null || !mounted) return;
    if (target == _pid) {
      showQyToast(context, '所选项目已在该目录');
      return;
    }

    setState(() => _busy = true);
    try {
      await _repo.moveFiles(ids, target);
      if (!mounted) return;
      showQyToast(context, '已移动 ${ids.length} 项', success: true);
      _exitSelection();
      await _load();
    } on ApiException catch (error) {
      if (mounted) showQyToast(context, '移动失败：${error.message}', success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'files_screen#move');
      if (mounted) showQyToast(context, '移动失败，请稍后重试', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteIds(List<String> ids) async {
    if (ids.isEmpty || _busy) return;
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('移入回收站？'),
            content: Text(
              '共 ${ids.length} 项将移入回收站，可随时在回收站恢复。'
              '文件夹内的文件会一起移入。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('确认删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repo.deleteFiles(ids);
      if (!mounted) return;
      showQyToast(context, '已将 ${ids.length} 项移入回收站', success: true);
      _exitSelection();
      await _load();
    } on ApiException catch (error) {
      if (mounted) showQyToast(context, '删除失败：${error.message}', success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'files_screen#delete');
      if (mounted) showQyToast(context, '删除失败，请稍后重试', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showDetails(CloudFile file) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('项目详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _DetailRow(label: '名称', value: file.name),
            _DetailRow(label: '类型', value: file.isDir ? '文件夹' : '文件'),
            _DetailRow(label: '分类', value: file.isDir ? '—' : file.category.label),
            _DetailRow(
                label: '大小', value: file.isDir ? '—' : (file.sizeLabel.isEmpty ? '—' : file.sizeLabel)),
            _DetailRow(label: '创建时间', value: file.updatedLabel.isEmpty ? '—' : file.updatedLabel),
            _DetailRow(label: '节点 ID', value: file.id),
            _DetailRow(
                label: '所在目录',
                value: file.pid == 0 ? '根目录' : '#${file.pid}'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 单个文件 / 文件夹的操作菜单（行尾图标与文件夹卡片右上角共用）。
  Future<void> _showItemActions(CloudFile file) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: QyColors.ink),
                ),
              ),
            ),
            ListTile(
              dense: true,
              leading: Icon(file.isDir ? Icons.folder_open : Icons.visibility_outlined,
                  size: 20, color: QyColors.primary),
              title: Text(file.isDir ? '打开文件夹' : '打开预览',
                  style: const TextStyle(fontSize: 13.5)),
              onTap: () => Navigator.of(ctx).pop('open'),
            ),
            if (AdminGate.instance.isAdmin) ...<Widget>[
              ListTile(
                dense: true,
                leading: const Icon(Icons.drive_file_rename_outline,
                    size: 20, color: QyColors.primary),
                title: const Text('重命名', style: TextStyle(fontSize: 13.5)),
                onTap: () => Navigator.of(ctx).pop('rename'),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.drive_file_move_outline,
                    size: 20, color: QyColors.primary),
                title: const Text('移动到…', style: TextStyle(fontSize: 13.5)),
                onTap: () => Navigator.of(ctx).pop('move'),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline, size: 20, color: QyColors.coral),
                title: const Text('移入回收站',
                    style: TextStyle(fontSize: 13.5, color: QyColors.coral)),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            ],
            ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline, size: 20, color: QyColors.primary),
              title: const Text('查看详情', style: TextStyle(fontSize: 13.5)),
              onTap: () => Navigator.of(ctx).pop('details'),
            ),
            const SizedBox(height: 8),
          ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'open') {
      _openItem(file);
    } else if (action == 'rename') {
      await _rename(file);
    } else if (action == 'move') {
      await _moveIds(<String>[file.id]);
    } else if (action == 'delete') {
      await _deleteIds(<String>[file.id]);
    } else if (action == 'details') {
      _showDetails(file);
    }
  }

  void _openItem(CloudFile file) {
    if (_selectionMode) {
      _toggleSelected(file.id);
      return;
    }
    if (file.isDir) {
      _openFolder(file);
    } else {
      context.push(QyRoutes.preview, extra: file);
    }
  }

  // ---------------------------------------------------------------------------
  // FAB：上传 / 新建文件夹
  // ---------------------------------------------------------------------------

  Future<void> _showActions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('上传文件'),
              onTap: () {
                Navigator.of(ctx).pop();
                _upload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('新建文件夹'),
              onTap: () {
                Navigator.of(ctx).pop();
                _createFolder();
              },
            ),
          ],
          ),
        ),
      ),
    );
  }

  Future<void> _upload() async {
    try {
      final CloudFile? file = await UploadHelper.pickAndUpload(pid: _pid);
      if (file == null || !mounted) return;
      showQyToast(context, '已上传 ${file.name}', success: true);
      await _load();
    } on ApiException catch (error) {
      // 主动暂停（请求被取消）不是失败，传输页已显示 paused 状态。
      if (error.isCancelled || !mounted) return;
      showQyToast(context, '上传失败：${error.message}', success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'files_screen#upload');
      if (mounted) showQyToast(context, '上传失败：$error', success: false);
    }
  }

  Future<void> _createFolder() async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 255,
          decoration: const InputDecoration(hintText: '输入文件夹名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    if (name.contains('/') || name.contains('\\')) {
      showQyToast(context, '名称不能包含路径分隔符', success: false);
      return;
    }
    try {
      await _repo.createFolder(name, pid: _pid);
      if (!mounted) return;
      showQyToast(context, '文件夹已创建', success: true);
      await _load();
    } on ApiException catch (error) {
      if (mounted) showQyToast(context, '创建失败：${error.message}', success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'files_screen#mkdir');
      if (mounted) showQyToast(context, '创建失败，请稍后重试', success: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // 标题 / 面包屑 / 右上按钮 + 筛选胶囊 + 文件夹区固定不滚动，
    // 下方「文件」列表单独滚动；FAB（或批量操作栏）浮在底部。
    return ColoredBox(
      color: QyColors.canvas,
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ProtoNav(
                title: _selectionMode ? '已选 ${_selected.length} 项' : '全部文件',
                subtitle: _folderName,
                subIcon: _pid == 0 ? Icons.home : Icons.folder,
                actions: _selectionMode
                    ? <Widget>[
                        ProtoIconButton(
                          icon: Icons.close,
                          onTap: _exitSelection,
                        ),
                        ProtoIconButton(
                          icon: Icons.select_all,
                          onTap: _toggleSelectAll,
                        ),
                      ]
                    : <Widget>[
                        ProtoIconButton(
                          icon: Icons.search,
                          onTap: () => context.push(QyRoutes.search),
                        ),
                        ProtoIconButton(
                          icon: Icons.sort,
                          onTap: () {
                            _showSortSheet();
                          },
                        ),
                        ProtoIconButton(
                          icon: Icons.more_horiz,
                          onTap: () {
                            _showMoreSheet();
                          },
                        ),
                      ],
              ),
              ProtoChipRow(
                labels: _chips,
                activeIndex: _chip,
                onChanged: (int i) {
                  setState(() => _chip = i);
                  _load();
                },
              ),
              _FolderGrid(
                folders: _folders,
                selectionMode: _selectionMode,
                selected: _selected,
                onTap: _openItem,
                onMore: (CloudFile folder) {
                  _showItemActions(folder);
                },
              ),
              Expanded(
                child: ListView(
                  physics: qyProtoScrollPhysics,
                  padding: const EdgeInsets.only(bottom: 100),
                  children: <Widget>[
                    ProtoSectionHead(
                      title: '文件',
                      more: _sort.label,
                      moreIcon: Icons.expand_more,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                      onMore: () {
                        _showSortSheet();
                      },
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      QyEmptyState(
                        title: '加载失败',
                        description: _error!,
                        actionLabel: '重新加载',
                        onAction: () {
                          _load();
                        },
                      )
                    else if (_files.isEmpty)
                      const QyEmptyState(
                        title: '这里空空如也',
                        description: '当前分类下没有文件，试试上传或切换分类',
                      )
                    else ...<Widget>[
                      _FileList(
                        files: _files,
                        selectionMode: _selectionMode,
                        selected: _selected,
                        onTap: _openItem,
                        onMore: (CloudFile file) {
                          _showItemActions(file);
                        },
                      ),
                      ProtoFootNote(
                        '已显示全部 ${_files.length} 个文件',
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_selectionMode)
            Positioned(
              right: 18,
              bottom: 22,
              left: 18,
              child: _SelectionBar(
                count: _selected.length,
                busy: _busy,
                onMove: () {
                  _moveIds(_selectedIds());
                },
                onDelete: () {
                  _deleteIds(_selectedIds());
                },
              ),
            )
          else
            AdminOnly(
              child: Positioned(
                right: 18,
                bottom: 22,
                child: _Fab(onTap: () {
                  _showActions();
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 移动目标选择器
// ---------------------------------------------------------------------------

class _MovePickerDialog extends StatelessWidget {
  const _MovePickerDialog({
    required this.folders,
    required this.blocked,
    required this.currentPid,
  });

  final List<FolderEntry> folders;
  final Set<int> blocked;
  final int currentPid;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('移动到…'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (folders.isEmpty && currentPid == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '还没有任何文件夹，请先新建。',
                    style: TextStyle(fontSize: 12.5, color: QyColors.muted),
                  ),
                ),
              ListTile(
                dense: true,
                enabled: currentPid != 0,
                leading: const Icon(Icons.home_outlined,
                    size: 20, color: QyColors.primary),
                title: const Text('我的云盘（根目录）',
                    style: TextStyle(fontSize: 13)),
                subtitle: currentPid == 0
                    ? const Text('当前目录',
                        style: TextStyle(fontSize: 10.5, color: QyColors.hint))
                    : null,
                onTap: () => Navigator.of(context).pop(0),
              ),
              for (final FolderEntry folder in folders)
                ListTile(
                  dense: true,
                  enabled: !blocked.contains(folder.id) &&
                      folder.id != currentPid,
                  leading: const Icon(Icons.folder_outlined,
                      size: 20, color: QyColors.primary),
                  title: Text(
                    folder.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  subtitle: blocked.contains(folder.id)
                      ? const Text('不可移入自身子目录',
                          style: TextStyle(fontSize: 10.5, color: QyColors.coral))
                      : (folder.id == currentPid
                          ? const Text('当前目录',
                              style: TextStyle(
                                  fontSize: 10.5, color: QyColors.hint))
                          : null),
                  onTap: () => Navigator.of(context).pop(folder.id),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 68,
            child: Text(label,
                style: const TextStyle(fontSize: 11.5, color: QyColors.muted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 11.5, color: QyColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.busy,
    required this.onMove,
    required this.onDelete,
  });

  final int count;
  final bool busy;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x1A1F4899), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('已选 $count 项',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: QyColors.ink)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: (busy || count == 0) ? null : onMove,
            icon: const Icon(Icons.drive_file_move_outline, size: 17),
            label: const Text('移动', style: TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: (busy || count == 0) ? null : onDelete,
            icon: const Icon(Icons.delete_outline, size: 17, color: QyColors.coral),
            label: const Text('删除',
                style: TextStyle(fontSize: 12.5, color: QyColors.coral)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 文件夹 / 文件列表（保持原型视觉，接入真实交互）
// ---------------------------------------------------------------------------

class _FolderGrid extends StatelessWidget {
  const _FolderGrid({
    required this.folders,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onMore,
  });

  final List<CloudFile> folders;
  final bool selectionMode;
  final Set<String> selected;
  final ValueChanged<CloudFile> onTap;
  final ValueChanged<CloudFile> onMore;

  static const List<Color> _colors = <Color>[
    Color(0xFF4C8DFF),
    QyColors.mint,
    QyColors.amber,
    Color(0xFFA78BFF),
  ];

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) return const SizedBox.shrink();
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < folders.length; i += 2) {
      final CloudFile first = folders[i];
      final CloudFile? second = i + 1 < folders.length ? folders[i + 1] : null;
      rows.add(
        Row(
          children: <Widget>[
            _FolderCard(
              icon: Icons.folder,
              color: _colors[i % _colors.length],
              name: first.name,
              meta: first.updatedLabel,
              selected: selectionMode && selected.contains(first.id),
              selectionMode: selectionMode,
              onTap: () => onTap(first),
              onMore: () => onMore(first),
            ),
            if (second != null) ...<Widget>[
              const SizedBox(width: 10),
              _FolderCard(
                icon: Icons.folder,
                color: _colors[(i + 1) % _colors.length],
                name: second.name,
                meta: second.updatedLabel,
                selected: selectionMode && selected.contains(second.id),
                selectionMode: selectionMode,
                onTap: () => onTap(second),
                onMore: () => onMore(second),
              ),
            ],
          ],
        ),
      );
      rows.add(const SizedBox(height: 10));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(children: rows),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.icon,
    required this.color,
    required this.name,
    required this.meta,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onMore,
  });

  final IconData icon;
  final Color color;
  final String name;
  final String meta;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: QyTapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: QyColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(
              color: selected ? QyColors.primary : const Color(0xFFF3F6FC),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 28, color: color),
                  const Spacer(),
                  if (selectionMode)
                    Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18,
                      color: selected ? QyColors.primary : QyColors.hint,
                    )
                  else
                    QyTapScale(
                      onTap: onMore,
                      child: const Icon(Icons.more_horiz,
                          size: 17, color: QyColors.hint),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(name, style: ProtoText.name13w600,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(meta, style: ProtoText.label105),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({
    required this.files,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onMore,
  });

  final List<CloudFile> files;
  final bool selectionMode;
  final Set<String> selected;
  final ValueChanged<CloudFile> onTap;
  final ValueChanged<CloudFile> onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (final file in files)
            _FileRow(
              file: file,
              selected: selectionMode && selected.contains(file.id),
              selectionMode: selectionMode,
              onTap: () => onTap(file),
              onMore: () => onMore(file),
            ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onMore,
  });

  final CloudFile file;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onMore;

  static const Map<FileCategory, IconData> _icons = <FileCategory, IconData>{
    FileCategory.image: Icons.image,
    FileCategory.doc: Icons.table_chart,
    FileCategory.video: Icons.movie,
    FileCategory.music: Icons.audio_file,
    FileCategory.zip: Icons.folder_zip,
    FileCategory.other: Icons.insert_drive_file,
    FileCategory.all: Icons.insert_drive_file,
  };

  static const Map<FileCategory, Color> _tints = <FileCategory, Color>{
    FileCategory.image: QyColors.primary,
    FileCategory.doc: QyColors.mintDeep,
    FileCategory.video: QyColors.amberDeep,
    FileCategory.music: QyColors.violetDeep,
    FileCategory.zip: QyColors.pinkDeep,
    FileCategory.other: QyColors.sub,
    FileCategory.all: QyColors.sub,
  };

  static const Map<FileCategory, Color> _backgrounds = <FileCategory, Color>{
    FileCategory.image: QyColors.primaryLight,
    FileCategory.doc: QyColors.mintSoft,
    FileCategory.video: QyColors.amberSoft,
    FileCategory.music: QyColors.violetSoft,
    FileCategory.zip: QyColors.pinkSoft,
    FileCategory.other: QyColors.track,
    FileCategory.all: QyColors.track,
  };

  @override
  Widget build(BuildContext context) {
    final sub = <String>[
      if (file.sizeLabel.isNotEmpty) file.sizeLabel,
      if (file.updatedLabel.isNotEmpty) file.updatedLabel,
    ].join(' · ');
    return QyTapScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: const Border(top: BorderSide(color: QyColors.divider)),
          color: selected ? QyColors.primaryLight : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            ProtoTypeIcon(
              icon: _icons[file.category] ?? Icons.insert_drive_file,
              color: _tints[file.category] ?? QyColors.sub,
              background: _backgrounds[file.category] ?? QyColors.track,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: ProtoText.name135),
                  if (sub.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(sub, style: ProtoText.label105),
                  ],
                ],
              ),
            ),
            if (selectionMode)
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? QyColors.primary : QyColors.hint,
              )
            else
              QyTapScale(
                onTap: onMore,
                child: const Icon(Icons.more_vert, size: 20, color: QyColors.hint),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment(-0.77, -0.64),
            end: Alignment(0.77, 0.64),
            colors: <Color>[Color(0xFF3C7CFF), QyColors.primary],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0x992F6BFF), blurRadius: 24, offset: Offset(0, 12), spreadRadius: -6),
          ],
        ),
        child: const Icon(Icons.add, size: 26, color: QyColors.onDark),
      ),
    );
  }
}
