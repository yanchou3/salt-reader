import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

/// 带自定义请求头的网络图片。
///
/// 不少图片 CDN 做了反盗链：缺少 `Referer` 时一律返回 403（少数派的
/// `cdnfile.sspai.com` 实测就是如此）。Flutter 内置的 [NetworkImage] 不会
/// 发送 `Referer`，因此在所有平台上都无法加载这些图片。这里用自建的
/// [HttpClient] 把 `Referer` / `User-Agent` 补上。
class HeaderNetworkImage extends ImageProvider<HeaderNetworkImage> {
  HeaderNetworkImage(this.url, {this.headers = const <String, String>{}});

  final String url;
  final Map<String, String> headers;

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  @override
  Future<HeaderNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<HeaderNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
    HeaderNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _fetch(key, decode),
      scale: 1,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<String>('URL', key.url),
      ],
    );
  }

  Future<ui.Codec> _fetch(
    HeaderNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    final Uri uri = Uri.parse(key.url);
    final HttpClientRequest request = await _client.getUrl(uri);
    key.headers.forEach((String name, String value) {
      request.headers.set(name, value);
    });
    final HttpClientResponse response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw NetworkImageLoadException(statusCode: response.statusCode, uri: uri);
    }
    final Uint8List bytes = await consolidateHttpClientResponseBytes(response);
    if (bytes.isEmpty) {
      throw StateError('图片内容为空：$url');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is HeaderNetworkImage &&
      other.url == url &&
      mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(
        url,
        Object.hashAllUnordered(
          headers.entries.map(
            (MapEntry<String, String> e) => Object.hash(e.key, e.value),
          ),
        ),
      );
}

/// 把 HTML 里的 `<img>` 换成带 `Referer` 的 [HeaderNetworkImage]。
///
/// 只覆写图片 provider，尺寸 / 加载态 / 错误态等仍走 fwfh 内置实现。
class HeaderImageWidgetFactory extends WidgetFactory {
  HeaderImageWidgetFactory({required this.referer, required this.userAgent});

  final String? referer;
  final String userAgent;

  @override
  ImageProvider? imageProviderFromNetwork(String url) {
    if (url.isEmpty) {
      return null;
    }
    return HeaderNetworkImage(
      url,
      headers: <String, String>{
        'User-Agent': userAgent,
        if ((referer ?? '').isNotEmpty) 'Referer': referer!,
      },
    );
  }
}
