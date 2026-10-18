import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 「阅读模式」式的正文提取：当订阅源只给摘要时，抓取原文页面并抽出主内容。
class ReadableService {
  ReadableService(this._dio);

  final Dio _dio;

  static const String _userAgent =
      'Mozilla/5.0 (compatible; RssReader/1.0; +https://example.com/rss-reader)';

  Future<String?> extractMainHtml(String url) async {
    final Response<String> response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: <String, String>{
          'User-Agent': _userAgent,
          'Accept': 'text/html,application/xhtml+xml',
        },
      ),
    );
    final String raw = response.data ?? '';
    if (raw.trim().isEmpty) {
      return null;
    }
    return extractFromHtml(raw);
  }

  /// 从整页 HTML 中挑出正文容器并返回其内部 HTML。
  String? extractFromHtml(String html) {
    final dom.Document document = html_parser.parse(html);
    for (final String tag in <String>[
      'script',
      'style',
      'noscript',
      'nav',
      'footer',
      'aside',
      'form',
      'iframe',
      'svg',
    ]) {
      for (final dom.Element element in document.querySelectorAll(tag)) {
        element.remove();
      }
    }

    // 先试语义标签。
    for (final String selector in <String>['article', 'main', '[role=main]']) {
      final dom.Element? element = document.querySelector(selector);
      if (element != null && _paragraphScore(element) > 240) {
        return _clean(element.innerHtml);
      }
    }

    final List<dom.Element> candidates = <dom.Element>[];
    for (final dom.Element element in document.querySelectorAll('div, section')) {
      if (_paragraphScore(element) > 240) {
        candidates.add(element);
      }
    }
    if (candidates.isEmpty) {
      return null;
    }

    int maxScore = 0;
    for (final dom.Element element in candidates) {
      final int score = _paragraphScore(element);
      if (score > maxScore) {
        maxScore = score;
      }
    }

    // 在「包含约八成正文」的候选里挑最紧凑的那个（避免拿到整个页面包裹层）。
    final List<dom.Element> within = candidates
        .where((dom.Element e) => _paragraphScore(e) >= maxScore * 0.8)
        .toList()
      ..sort(
        (dom.Element a, dom.Element b) =>
            a.text.length.compareTo(b.text.length),
      );

    return _clean(within.first.innerHtml);
  }

  int _paragraphScore(dom.Element element) {
    int total = 0;
    for (final dom.Element p in element.querySelectorAll('p')) {
      total += p.text.trim().length;
    }
    return total;
  }

  String? _clean(String html) {
    final String trimmed = html.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
