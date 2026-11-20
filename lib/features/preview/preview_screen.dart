import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';
import '../../core/config/admin_gate.dart';

/// 07 文件预览：按文件类型在线查看（图片/视频/音频/文本/PDF 内联，
/// 其他类型走「下载并用系统应用打开」），底部工具全部接真实接口。
///
/// PDF 走 `/api/preview/url` 签发的短期能力 URL → 下载到私有临时目录 →
/// 交给原生 PDFView（AndroidPdfViewer / PDFKit）渲染；带缓存、续签、密码、
/// 翻页与失败降级，契约见 docs/BACKEND.md 2.15。
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.file});

  final CloudFile file;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final CloudRepository _repo = CloudRepository();

  PreviewInfo? _info;
  VideoPlayerController? _video;
  String? _textContent;
  String? _error;
  String? _title;
  bool _loading = true;

  // PDF 内联预览状态（缓存路径、准备进度、渲染错误、页码、打开密码）。
  String? _pdfPath;
  String? _pdfError;
  bool _pdfPreparing = false;
  double _pdfProgress = 0;
  int _pdfPages = 0;
  int _pdfPage = 0;
  int _pdfReloadKey = 0;
  String? _pdfPassword;
  PDFViewController? _pdfController;

  @override
  void initState() {
    super.initState();
    _title = widget.file.name;
    _load();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // 换取短期签名 URL：<img>/<video> 无法附加 Authorization 头，
      // 因此由后端签发 HMAC 能力 URL（见 docs/BACKEND.md）。
      final info = await _repo.previewInfo(widget.file.id);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
      if (info.isVideo || info.isAudio) {
        await _initVideo(info.url);
      } else if (info.isText) {
        await _loadText(info.url);
      } else if (info.isPdf) {
        await _preparePdf(info);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _initVideo(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      await controller.play();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'preview_screen#1');
      // 播放器初始化失败时保留降级卡片，用户仍可下载后用系统播放器查看。
    }
  }

  Future<void> _loadText(String url) async {
    try {
      final response = await Dio().get<String>(url);
      if (!mounted) return;
      setState(() => _textContent = response.data ?? '');
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'preview_screen#2');
      // 文本拉取失败不阻塞其他操作，展示下载入口即可。
    }
  }

  /// PDF：准备本地文件（缓存 / 续签 / 下载 / 长度校验），交给原生渲染器。
  Future<void> _preparePdf(PreviewInfo info, {bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _pdfPreparing = true;
      _pdfError = null;
      _pdfProgress = 0;
      if (forceRefresh) {
        _pdfPath = null;
        _pdfController = null;
        _pdfPages = 0;
        _pdfPage = 0;
        _pdfReloadKey++;
      }
    });
    try {
      if (forceRefresh) {
        await _repo.clearPdfPreviewCache(
          fileId: widget.file.id,
          sizeBytes: info.sizeBytes,
        );
      }
      final String path = await _repo.preparePdfPreview(
        fileId: widget.file.id,
        info: info,
        onProgress: (double value) {
          if (mounted) setState(() => _pdfProgress = value);
        },
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _pdfPath = path;
        _pdfPreparing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfError = e.message;
        _pdfPreparing = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'preview_screen#pdf');
      if (!mounted) return;
      setState(() {
        _pdfError = error.toString();
        _pdfPreparing = false;
      });
    }
  }

  /// 加密 PDF：输入打开密码后重建 PDFView（key 变化触发原生视图重建）。
  Future<void> _askPdfPassword() async {
    final TextEditingController controller = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('PDF 打开密码'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(hintText: '留空则清除密码'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() {
      _pdfPassword = value.isEmpty ? null : value;
      _pdfError = null;
      _pdfReloadKey++;
    });
  }

  void _gotoPage(int target) {
    final PDFViewController? controller = _pdfController;
    if (controller == null || _pdfPages <= 0) return;
    unawaited(controller.setPage(target.clamp(0, _pdfPages - 1)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ColoredBox(
        color: QyColors.darkBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 10),
              child: Row(
                children: <Widget>[
                  ProtoIconButton(
                    icon: Icons.arrow_back,
                    color: const Color(0xFFDDE3EE),
                    onTap: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      _title ?? widget.file.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE6EAF2),
                      ),
                    ),
                  ),
                  ProtoIconButton(
                    icon: Icons.more_horiz,
                    color: const Color(0xFFDDE3EE),
                    onTap: _showDetails,
                  ),
                ],
              ),
            ),
            Expanded(child: _content()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${widget.file.updatedLabel} · ${widget.file.category.label}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8D99AD)),
                    ),
                  ),
                  Text(
                    widget.file.sizeLabel,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8D99AD)),
                  ),
                ],
              ),
            ),
            _Tools(
              onShare: _share,
              onDownload: _download,
              onRename: _rename,
              onDelete: _delete,
              onDetails: _showDetails,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: QyColors.onDark),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 46, color: Color(0xAAFFFFFF)),
              const SizedBox(height: 12),
              Text(
                '预览失败：$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB9C3D4)),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final info = _info!;
    if (info.isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Image.network(
            info.url,
            fit: BoxFit.contain,
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: QyColors.onDark),
              );
            },
            errorBuilder: (_, __, ___) => const _Unsupported(
              icon: Icons.broken_image_outlined,
              hint: '图片加载失败，可尝试下载查看',
            ),
          ),
        ),
      );
    }
    final VideoPlayerController? video = _video;
    if ((info.isVideo || info.isAudio) &&
        video != null &&
        video.value.isInitialized) {
      if (info.isAudio) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.audiotrack, size: 72, color: Color(0xAAFFFFFF)),
              const SizedBox(height: 20),
              _PlayerControls(controller: video),
            ],
          ),
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: video.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              VideoPlayer(video),
              _PlayerControls(controller: video),
            ],
          ),
        ),
      );
    }
    if (info.isText && _textContent != null) {
      return Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: SelectableText(
            _textContent!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Color(0xFFE6EAF2),
            ),
          ),
        ),
      );
    }
    if (info.isPdf) return _pdfContent(info);
    return _Unsupported(
      icon: _fallbackIcon(widget.file.category),
      hint: '该格式暂不支持内联查看，可下载后打开',
    );
  }

  Widget _pdfContent(PreviewInfo info) {
    if (_pdfPreparing) {
      final int percent = (_pdfProgress * 100).clamp(0, 100).toInt();
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(color: QyColors.onDark),
              const SizedBox(height: 16),
              Text(
                '正在准备 PDF · $percent%',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB9C3D4)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: _pdfProgress > 0 ? _pdfProgress : null,
                  color: QyColors.primary,
                  backgroundColor: const Color(0x33FFFFFF),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final String? path = _pdfPath;
    final String? error = _pdfError;
    if (path == null || error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.picture_as_pdf_outlined,
                  size: 52, color: Color(0xAAFFFFFF)),
              const SizedBox(height: 14),
              Text(
                error == null ? 'PDF 暂时无法加载' : 'PDF 加载失败：$error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB9C3D4)),
              ),
              const SizedBox(height: 6),
              const Text(
                '加密文件可输入打开密码；文件损坏或过大时请下载后查看',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF8D99AD)),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _PdfAction(
                    label: '重新加载',
                    onTap: () => _preparePdf(info, forceRefresh: true),
                  ),
                  _PdfAction(label: '下载后打开', onTap: _download),
                  _PdfAction(label: '打开密码', onTap: _askPdfPassword),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: PDFView(
            // path / 密码 / 刷新序号任一变化都重建原生视图，避免复用旧句柄。
            key: ValueKey<String>('$path#${_pdfPassword ?? ''}#$_pdfReloadKey'),
            filePath: path,
            password: _pdfPassword,
            enableSwipe: true,
            swipeHorizontal: false,
            pageFling: true,
            autoSpacing: true,
            backgroundColor: QyColors.darkBg,
            onRender: (pages) {
              if (!mounted) return;
              setState(() => _pdfPages = pages is int ? pages : 0);
            },
            onPageChanged: (page, total) {
              if (!mounted) return;
              setState(() {
                _pdfPage = page is int ? page : 0;
                if (total is int) _pdfPages = total;
              });
            },
            onViewCreated: (PDFViewController controller) {
              _pdfController = controller;
            },
            onError: (renderError) {
              ErrorReporter.report(renderError ?? 'PDF 渲染失败',
                  StackTrace.current, context: 'preview_screen#pdf-render');
              if (!mounted) return;
              setState(() => _pdfError = '无法渲染该 PDF：$renderError');
            },
            onPageError: (page, pageError) {
              ErrorReporter.report(pageError ?? 'PDF 单页渲染失败',
                  StackTrace.current, context: 'preview_screen#pdf-page');
            },
          ),
        ),
        _PdfBar(
          page: _pdfPage,
          pages: _pdfPages,
          onPrev: () => _gotoPage(_pdfPage - 1),
          onNext: () => _gotoPage(_pdfPage + 1),
          onReload: () => _preparePdf(info, forceRefresh: true),
          onDownload: _download,
          onPassword: _askPdfPassword,
        ),
      ],
    );
  }

  static IconData _fallbackIcon(FileCategory category) => switch (category) {
        FileCategory.image => Icons.image,
        FileCategory.video => Icons.movie,
        FileCategory.music => Icons.audiotrack,
        FileCategory.zip => Icons.folder_zip,
        FileCategory.doc => Icons.description,
        FileCategory.other || FileCategory.all => Icons.insert_drive_file,
      };

  Future<void> _share() async {
    try {
      final String url = await _repo.shareFile(
        widget.file.id,
        expireDays: 7,
      );
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      showQyToast(context, '分享链接已复制', success: true);
    } on ApiException catch (e) {
      if (mounted) showQyToast(context, '分享失败：${e.message}');
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'preview_screen#3');
      if (mounted) showQyToast(context, '分享失败，请稍后重试');
    }
  }

  Future<void> _download() async {
    try {
      final String path = await _repo.downloadFile(
        fileId: widget.file.id,
        name: _title ?? widget.file.name,
      );
      await OpenFilex.open(path);
      if (!mounted) return;
      showQyToast(context, '已下载到应用目录并尝试打开', success: true);
    } on ApiException catch (e) {
      // 主动暂停（CancelToken 取消）不是下载失败，状态已由传输任务模型落地。
      if (e.isCancelled || !mounted) return;
      showQyToast(context, '下载失败：${e.message}');
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'preview_screen#4');
      if (mounted) showQyToast(context, '下载失败，请稍后重试');
    }
  }

  Future<void> _rename() async {
    final TextEditingController controller =
        TextEditingController(text: _title ?? widget.file.name);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新文件名'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    try {
      await _repo.renameFile(widget.file.id, result);
      if (!mounted) return;
      setState(() => _title = result);
      showQyToast(context, '已重命名', success: true);
    } on ApiException catch (e) {
      if (mounted) showQyToast(context, '重命名失败：${e.message}');
    }
  }

  Future<void> _delete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定将「${_title ?? widget.file.name}」移入回收站吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.deleteFiles(<String>[widget.file.id]);
      if (!mounted) return;
      showQyToast(context, '已移入回收站', success: true);
      context.go(QyRoutes.files);
    } on ApiException catch (e) {
      if (mounted) showQyToast(context, '删除失败：${e.message}');
    }
  }

  void _showDetails() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C2433),
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '文件详情',
              style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _DetailRow(label: '文件名', value: _title ?? widget.file.name),
            _DetailRow(label: '类型', value: widget.file.category.label),
            _DetailRow(label: '大小', value: widget.file.sizeLabel),
            _DetailRow(label: '上传时间', value: widget.file.updatedLabel),
            _DetailRow(label: '文件 ID', value: widget.file.id),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8D99AD))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFFE6EAF2))),
          ),
        ],
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (BuildContext context, VideoPlayerValue value, Widget? child) {
        final double ratio =
            value.duration.inMilliseconds <= 0
                ? 0
                : value.position.inMilliseconds /
                    value.duration.inMilliseconds;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  color: QyColors.primary,
                  backgroundColor: const Color(0x66FFFFFF),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported({required this.icon, required this.hint});

  final IconData icon;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 72, color: const Color(0xAAFFFFFF)),
          const SizedBox(height: 16),
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB9C3D4)),
          ),
        ],
      ),
    );
  }
}

class _PdfAction extends StatelessWidget {
  const _PdfAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0x66FFFFFF)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 11),
      ),
      child: Text(label),
    );
  }
}

class _PdfBar extends StatelessWidget {
  const _PdfBar({
    required this.page,
    required this.pages,
    required this.onPrev,
    required this.onNext,
    required this.onReload,
    required this.onDownload,
    required this.onPassword,
  });

  final int page;
  final int pages;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onReload;
  final VoidCallback onDownload;
  final VoidCallback onPassword;

  @override
  Widget build(BuildContext context) {
    final bool ready = pages > 0;
    return Container(
      height: 46,
      color: const Color(0xFF141C29),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '上一页',
            icon: const Icon(Icons.chevron_left, color: Color(0xFFC6CFDE)),
            onPressed: ready && page > 0 ? onPrev : null,
          ),
          Expanded(
            child: Text(
              ready ? '第 ${page + 1} / $pages 页' : 'PDF 加载中',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFFB9C3D4)),
            ),
          ),
          IconButton(
            tooltip: '下一页',
            icon: const Icon(Icons.chevron_right, color: Color(0xFFC6CFDE)),
            onPressed: ready && page < pages - 1 ? onNext : null,
          ),
          IconButton(
            tooltip: '重新加载',
            icon: const Icon(Icons.refresh, size: 19, color: Color(0xFFC6CFDE)),
            onPressed: onReload,
          ),
          IconButton(
            tooltip: '打开密码',
            icon: const Icon(Icons.lock_outline, size: 19, color: Color(0xFFC6CFDE)),
            onPressed: onPassword,
          ),
          IconButton(
            tooltip: '下载后用系统应用打开',
            icon: const Icon(Icons.download, size: 19, color: Color(0xFFC6CFDE)),
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.onShare,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
    required this.onDetails,
  });

  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          AdminOnly(
            child: _Tool(icon: Icons.share, label: '分享', onTap: onShare),
          ),
          _Tool(icon: Icons.download, label: '下载', onTap: onDownload),
          AdminOnly(
            child: _Tool(icon: Icons.edit, label: '重命名', onTap: onRename),
          ),
          AdminOnly(
            child: _Tool(icon: Icons.delete_outline, label: '删除', onTap: onDelete),
          ),
          _Tool(icon: Icons.info, label: '详情', onTap: onDetails),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 21, color: const Color(0xFFC6CFDE)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFC6CFDE))),
          ],
        ),
      ),
    );
  }
}
