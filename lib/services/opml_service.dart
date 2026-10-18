import 'package:xml/xml.dart';

import '../data/models/feed.dart';

/// OPML 里的一条订阅。
class OpmlEntry {
  const OpmlEntry({
    required this.title,
    required this.url,
    this.group = Feed.defaultGroup,
  });

  final String title;
  final String url;
  final String group;
}

/// OPML 2.0 的生成与解析（支持分组：分组会表现为嵌套 outline）。
class OpmlService {
  OpmlService._();

  static String build(List<Feed> feeds, {String title = '椒盐阅读订阅'}) {
    final Map<String, List<Feed>> grouped = <String, List<Feed>>{};
    for (final Feed feed in feeds) {
      (grouped[feed.group] ??= <Feed>[]).add(feed);
    }

    final XmlBuilder builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'opml',
      attributes: <String, String>{'version': '2.0'},
      nest: () {
        builder.element('head', nest: () {
          builder.element('title', nest: title);
        });
        builder.element('body', nest: () {
          for (final MapEntry<String, List<Feed>> entry in grouped.entries) {
            if (entry.key == Feed.defaultGroup) {
              for (final Feed feed in entry.value) {
                _writeFeed(builder, feed);
              }
            } else {
              builder.element(
                'outline',
                attributes: <String, String>{
                  'text': entry.key,
                  'title': entry.key,
                },
                nest: () {
                  for (final Feed feed in entry.value) {
                    _writeFeed(builder, feed);
                  }
                },
              );
            }
          }
        });
      },
    );
    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  static void _writeFeed(XmlBuilder builder, Feed feed) {
    builder.element(
      'outline',
      attributes: <String, String>{
        'type': 'rss',
        'text': feed.title,
        'title': feed.title,
        'xmlUrl': feed.url,
        if (feed.siteUrl != null && feed.siteUrl!.isNotEmpty)
          'htmlUrl': feed.siteUrl!,
      },
    );
  }

  /// 解析 OPML：把带 xmlUrl 的 outline 收为订阅，其父 outline 的名字作为分组。
  static List<OpmlEntry> parse(String xmlText) {
    final XmlDocument document = XmlDocument.parse(xmlText);
    final List<OpmlEntry> entries = <OpmlEntry>[];
    final Set<String> seen = <String>{};

    void walk(XmlElement element, String group) {
      for (final XmlElement child in element.childElements) {
        if (child.name.local != 'outline') {
          continue;
        }
        final String? url = child.getAttribute('xmlUrl') ??
            child.getAttribute('xmlurl') ??
            child.getAttribute('XMLUrl');
        if (url != null && url.trim().isNotEmpty) {
          final String trimmed = url.trim();
          if (!seen.add(trimmed)) {
            continue;
          }
          entries.add(
            OpmlEntry(
              title: child.getAttribute('text') ??
                  child.getAttribute('title') ??
                  trimmed,
              url: trimmed,
              group: group,
            ),
          );
        } else {
          final String groupName = child.getAttribute('text') ??
              child.getAttribute('title') ??
              group;
          walk(child, groupName);
        }
      }
    }

    final Iterable<XmlElement> bodies = document.findAllElements('body');
    if (bodies.isEmpty) {
      walk(document.rootElement, Feed.defaultGroup);
    } else {
      for (final XmlElement body in bodies) {
        walk(body, Feed.defaultGroup);
      }
    }
    return entries;
  }
}
