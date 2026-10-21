import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/header_image.dart';

/// 全屏看图：双指 / 滚轮缩放，拖动平移，双击在 1× 与 2× 之间切换。
///
/// 复用正文的 [HeaderNetworkImage]，所以打开时直接读已经缓存到本机的图片。
Future<void> showImageViewer(
  BuildContext context, {
  required String url,
  String? referer,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext context) =>
          _ImageViewerPage(url: url, referer: referer),
    ),
  );
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({required this.url, this.referer});

  final String url;
  final String? referer;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
    } else {
      _transform.value = Matrix4.diagonal3Values(2, 2, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image(
                    image: HeaderNetworkImage(
                      widget.url,
                      headers: <String, String>{
                        'User-Agent': _userAgent,
                        if (widget.referer != null)
                          'Referer': widget.referer!,
                      },
                    ),
                    fit: BoxFit.contain,
                    frameBuilder: (
                      BuildContext context,
                      Widget child,
                      int? frame,
                      bool wasSynchronouslyLoaded,
                    ) {
                      if (wasSynchronouslyLoaded || frame != null) {
                        return child;
                      }
                      return const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stack,
                    ) =>
                        const Center(
                      child: Text(
                        '图片加载失败',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  tooltip: '关闭',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
