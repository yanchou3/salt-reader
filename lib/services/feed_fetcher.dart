import 'package:dio/dio.dart';
import 'package:rss_dart/dart_rss.dart';
import 'package:rss_dart/domain/rss1_feed.dart';
import 'package:rss_dart/domain/rss1_item.dart';

import '../data/models/article.dart';
import '../data/models/feed.dart';

/// 一次抓取的结果。
class FetchedFeed {
  FetchedFeed({
    required this.title,
    required this.siteUrl,
    required this.items,
  });

  final String title;
  final String? siteUrl;
  final List<Article> items;
}

/// 拉取并解析 RSS / Atom 订阅源。
///
/// 关键点：正文优先取 `content:encoded`（全文），只有它缺失时才回退到
/// `description`（通常只是摘要）。这正是之前「看不到原文」的原因。
class FeedFetcher {
  FeedFetcher(this._dio);

  final Dio _dio;

  static const String _userAgent =
      'Mozilla/5.0 (compatible; RssReader/1.0; +https://example.com/rss-reader)';

  Future<FetchedFeed> fetch(Feed feed) async {
    final Response<String> response = await _dio.get<String>(
      feed.url,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: <String, String>{
          'User-Agent': _userAgent,
          'Accept':
              'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
        },
      ),
    );

    final String xmlText = response.data ?? '';
    if (xmlText.trim().isEmpty) {
      throw const FormatException('订阅源返回了空内容，请检查地址是否正确');
    }
    _ensureNotHtml(xmlText);

    final RssVersion version;
    try {
      version = WebFeed.detectRssVersion(xmlText);
    } catch (error) {
      throw FormatException('无法解析为 RSS/Atom：$error');
    }

    switch (version) {
      case RssVersion.rss2:
        return _parseRss2(feed, xmlText);
      case RssVersion.atom:
        return _parseAtom(feed, xmlText);
      case RssVersion.rss1:
        return _parseRss1(feed, xmlText);
      case RssVersion.unknown:
        throw const FormatException(
          '返回的内容不是 RSS/Atom，请确认填的是订阅源的 xml 地址',
        );
    }
  }

  /// 不少站点会把 RSS 地址打成网页（甚至把 404 也用 200 返回）。
  ///
  /// 直接报「无法识别的格式」用户看不出问题在哪，这里给出更明确的提示，
  /// 尽量把网页标题也带出来，方便定位。
  void _ensureNotHtml(String text) {
    String head = text.trimLeft();
    if (head.startsWith('\uFEFF')) {
      head = head.substring(1).trimLeft();
    }
    final String lowered = head.toLowerCase();
    if (!lowered.startsWith('<!doctype html') && !lowered.startsWith('<html')) {
      return;
    }
    final RegExpMatch? match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    final String title = (match?.group(1) ?? '').trim();
    throw FormatException(
      '这个地址返回的是网页，不是 RSS/Atom 订阅源'
      '${title.isEmpty ? '' : '（网页标题：$title）'}。'
      '请填该站真正的 xml / rss 地址。',
    );
  }

  FetchedFeed _parseRss2(Feed feed, String xmlText) {
    final RssFeed rss = RssFeed.parse(xmlText);
    final String title = (rss.title ?? '').trim();
    final String feedTitle = title.isEmpty ? feed.title : title;

    final List<Article> items = <Article>[];
    for (final RssItem item in rss.items) {
      final String? link = _clean(item.link);
      items.add(
        Article(
          id: _articleId(feed.id, link, item.guid, item.title, item.pubDate),
          feedId: feed.id,
          feedTitle: feedTitle,
          title: _clean(item.title) ?? '（无标题）',
          link: link,
          body: _pickBody(item.content?.value, item.description),
          published: SafeParseDateTime.safeParse(item.pubDate),
        ),
      );
    }
    return FetchedFeed(
      title: title,
      siteUrl: _clean(rss.link),
      items: items,
    );
  }

  FetchedFeed _parseAtom(Feed feed, String xmlText) {
    final AtomFeed atom = AtomFeed.parse(xmlText);
    final String title = (atom.title ?? '').trim();
    final String feedTitle = title.isEmpty ? feed.title : title;

    final List<Article> items = <Article>[];
    for (final AtomItem item in atom.items) {
      final String? link = _atomLink(item.links);
      items.add(
        Article(
          id: _articleId(
            feed.id,
            link,
            item.id,
            item.title,
            item.updated ?? item.published,
          ),
          feedId: feed.id,
          feedTitle: feedTitle,
          title: _clean(item.title) ?? '（无标题）',
          link: link,
          body: _pickBody(item.content, item.summary),
          published: SafeParseDateTime.safeParse(item.updated) ??
              SafeParseDateTime.safeParse(item.published),
        ),
      );
    }
    return FetchedFeed(
      title: title,
      siteUrl: _atomLink(atom.links),
      items: items,
    );
  }

  FetchedFeed _parseRss1(Feed feed, String xmlText) {
    final Rss1Feed rss1 = Rss1Feed.parse(xmlText);
    final String title = (rss1.title ?? rss1.dc?.title ?? '').trim();
    final String feedTitle = title.isEmpty ? feed.title : title;

    final List<Article> items = <Article>[];
    for (final Rss1Item item in rss1.items) {
      final String? link = _clean(item.link);
      final String? date = item.dc?.date;
      items.add(
        Article(
          id: _articleId(feed.id, link, null, item.title, date),
          feedId: feed.id,
          feedTitle: feedTitle,
          title: _clean(item.title) ?? '（无标题）',
          link: link,
          body: _pickBody(
            item.content?.value,
            _pickBody(item.description, item.dc?.description),
          ),
          published: SafeParseDateTime.safeParse(date),
        ),
      );
    }
    return FetchedFeed(
      title: title,
      siteUrl: _clean(rss1.link),
      items: items,
    );
  }

  /// 优先 rel 为 alternate / 未声明 rel 的链接，避免拿到 feed 自身的 rel=self。
  String? _atomLink(List<AtomLink> links) {
    String? fallback;
    for (final AtomLink link in links) {
      final String? href = _clean(link.href);
      if (href == null) {
        continue;
      }
      fallback ??= href;
      final String? rel = link.rel;
      if (rel == null || rel == 'alternate') {
        return href;
      }
    }
    return fallback;
  }

  /// 主内容与备用内容取更长的那个（全文通常更长）。
  String _pickBody(String? primary, String? secondary) {
    final String a = (primary ?? '').trim();
    final String b = (secondary ?? '').trim();
    if (a.isEmpty) {
      return b;
    }
    if (b.isEmpty) {
      return a;
    }
    return a.length >= b.length ? a : b;
  }

  String _articleId(
    String feedId,
    String? link,
    String? guid,
    String? title,
    String? date,
  ) {
    final String key =
        link ?? _clean(guid) ?? '${title ?? ''}|${date ?? ''}';
    return '$feedId::${stableHash(key)}';
  }

  String? _clean(String? value) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// 稳定的字符串哈希：跨进程一致（`String.hashCode` 不保证稳定）。
String stableHash(String input) {
  int hash = 0x811c9dc5;
  for (int i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
