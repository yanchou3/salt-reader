import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 把 HTML 片段里的相对 URL 补全为绝对 URL。
///
/// 主要解决两个真实问题：
/// 1. 正文里的 `<img src="/img/a.png">` 是相对路径，`NetworkImage` 无法加载；
/// 2. 很多站点用懒加载，真实地址在 `data-src` / `data-original` / `srcset` 里，
///    而 `src` 只是占位图。
String resolveRelativeUrls(String html, String? baseUrl) {
  if (html.isEmpty || baseUrl == null || baseUrl.trim().isEmpty) {
    return html;
  }
  final Uri? base = Uri.tryParse(baseUrl.trim());
  if (base == null || !base.hasScheme) {
    return html;
  }

  try {
    final dom.Document document = html_parser.parse(html);

    for (final dom.Element img in document.querySelectorAll('img')) {
      final String? raw = _pickImageSource(img);
      if (raw == null) {
        continue;
      }
      img.attributes['src'] = base.resolve(raw).toString();
      img.attributes.remove('data-src');
      img.attributes.remove('data-original');
      img.attributes.remove('srcset');
      img.attributes.remove('data-srcset');
    }

    for (final dom.Element anchor in document.querySelectorAll('a')) {
      final String? href = anchor.attributes['href'];
      if (href == null || href.trim().isEmpty || href.startsWith('#')) {
        continue;
      }
      anchor.attributes['href'] = base.resolve(href.trim()).toString();
    }

    final dom.Element? body = document.body;
    return body == null ? html : body.innerHtml;
  } catch (_) {
    return html;
  }
}

String? _pickImageSource(dom.Element img) {
  final Map<Object, String> attrs = img.attributes;
  for (final String key in <String>[
    'data-src',
    'data-original',
    'data-lazy-src',
    'src',
  ]) {
    final String? value = attrs[key]?.trim();
    if (value != null && value.isNotEmpty && !value.startsWith('data:image/gif')) {
      return value;
    }
  }
  for (final String key in <String>['srcset', 'data-srcset']) {
    final String? value = attrs[key]?.trim();
    if (value != null && value.isNotEmpty) {
      final String first = value.split(',').first.trim().split(' ').first;
      if (first.isNotEmpty) {
        return first;
      }
    }
  }
  final String? src = attrs['src']?.trim();
  return (src != null && src.isNotEmpty) ? src : null;
}
