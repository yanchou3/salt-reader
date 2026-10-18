import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/feed_fetcher.dart';
import '../services/opml_service.dart';
import '../services/readable_service.dart';
import '../services/webdav_client.dart';
import 'models/article.dart';
import 'models/feed.dart';

/// 全局状态与数据入口。
///
/// M3 阶段用「内存列表 + shared_preferences(JSON)」持久化；
/// 后续接入 Drift 后这里会换成仓储层，UI 不必改动。
class AppStore extends ChangeNotifier {
  AppStore._();

  static final AppStore instance = AppStore._();

  static const String _kFeeds = 'feeds_v1';
  static const String _kArticles = 'articles_v1';
  static const String _kDeleted = 'deleted_feeds_v1';
  static const String _kStateTs = 'state_ts_v1';
  static const String _kWebdavUrl = 'webdav_url';
  static const String _kWebdavUser = 'webdav_user';
  static const String _kWebdavPass = 'webdav_pass';
  static const String _kReaderFont = 'reader_font_scale';
  static const String _kReaderLine = 'reader_line_height';
  static const String _kReaderWidth = 'reader_max_width';
  static const String _kThemeMode = 'theme_mode';
  static const int _maxArticles = 300;

  final Dio _dio = Dio();
  late final FeedFetcher _fetcher = FeedFetcher(_dio);
  late final ReadableService _readable = ReadableService(_dio);

  final List<Feed> _feeds = <Feed>[];
  final List<Article> _articles = <Article>[];
  final List<DeletedFeed> _deletedFeeds = <DeletedFeed>[];
  final Map<String, int> _stateTimestamps = <String, int>{};

  String? _webdavUrl;
  String? _webdavUser;
  String? _webdavPassword;

  double _readerFontScale = 1.0;
  double _readerLineHeight = 1.7;
  double _readerMaxWidth = 720.0;
  ThemeMode _themeMode = ThemeMode.system;

  bool _loading = false;
  String? _lastError;
  bool _fetchingFullText = false;

  bool get fetchingFullText => _fetchingFullText;

  List<Feed> get feeds => List<Feed>.unmodifiable(_feeds);
  bool get loading => _loading;
  String? get lastError => _lastError;
  bool get hasFeeds => _feeds.isNotEmpty;

  String? get webdavUrl => _webdavUrl;
  String? get webdavUser => _webdavUser;
  String? get webdavPassword => _webdavPassword;
  bool get webdavConfigured =>
      (_webdavUrl ?? '').isNotEmpty &&
      (_webdavUser ?? '').isNotEmpty &&
      (_webdavPassword ?? '').isNotEmpty;

  double get readerFontScale => _readerFontScale;
  double get readerLineHeight => _readerLineHeight;
  double get readerMaxWidth => _readerMaxWidth;
  ThemeMode get themeMode => _themeMode;

  /// 分组名列表（未分组优先，其余按名称排序）。
  List<String> get groups {
    final Set<String> names = _feeds.map((Feed f) => f.group).toSet();
    final List<String> list = names.toList()..sort();
    if (list.remove(Feed.defaultGroup)) {
      list.insert(0, Feed.defaultGroup);
    }
    return list;
  }

  /// 某篇文章所属订阅源的分组名。
  String groupOfFeed(String feedId) {
    for (final Feed feed in _feeds) {
      if (feed.id == feedId) {
        return feed.group;
      }
    }
    return Feed.defaultGroup;
  }

  List<Article> get unreadArticles =>
      _sorted(_articles.where((Article a) => !a.read).toList());
  /// 某个订阅源的全部文章（按时间倒序）。
  List<Article> articlesOfFeed(String feedId) =>
      _sorted(_articles.where((Article a) => a.feedId == feedId).toList());

  /// 某个订阅源的未读数。
  int unreadCountOfFeed(String feedId) =>
      _articles.where((Article a) => a.feedId == feedId && !a.read).length;

  List<Article> get allArticles => _sorted(List<Article>.of(_articles));
  List<Article> get starredArticles =>
      _sorted(_articles.where((Article a) => a.starred).toList());
  int get unreadCount => _articles.where((Article a) => !a.read).length;

  List<Article> _sorted(List<Article> list) {
    list.sort((Article a, Article b) {
      final DateTime da = a.published ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime db = b.published ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return list;
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      final String? feedsRaw = prefs.getString(_kFeeds);
      if (feedsRaw != null) {
        final List<dynamic> list = jsonDecode(feedsRaw) as List<dynamic>;
        _feeds
          ..clear()
          ..addAll(
            list.map((dynamic e) => Feed.fromJson(e as Map<String, dynamic>)),
          );
      }
      final String? articlesRaw = prefs.getString(_kArticles);
      if (articlesRaw != null) {
        final List<dynamic> list = jsonDecode(articlesRaw) as List<dynamic>;
        _articles
          ..clear()
          ..addAll(
            list.map((dynamic e) => Article.fromJson(e as Map<String, dynamic>)),
          );
      }
      final String? deletedRaw = prefs.getString(_kDeleted);
      if (deletedRaw != null) {
        final List<dynamic> list = jsonDecode(deletedRaw) as List<dynamic>;
        _deletedFeeds
          ..clear()
          ..addAll(
            list.map(
              (dynamic e) => DeletedFeed.fromJson(e as Map<String, dynamic>),
            ),
          );
      }
      final String? stateTsRaw = prefs.getString(_kStateTs);
      if (stateTsRaw != null) {
        final Map<String, dynamic> map =
            jsonDecode(stateTsRaw) as Map<String, dynamic>;
        _stateTimestamps
          ..clear()
          ..addAll(
            map.map(
              (String key, dynamic value) =>
                  MapEntry<String, int>(key, (value as num).toInt()),
            ),
          );
      }
      _webdavUrl = prefs.getString(_kWebdavUrl);
      _webdavUser = prefs.getString(_kWebdavUser);
      _webdavPassword = prefs.getString(_kWebdavPass);
      _readerFontScale = prefs.getDouble(_kReaderFont) ?? 1.0;
      _readerLineHeight = prefs.getDouble(_kReaderLine) ?? 1.7;
      _readerMaxWidth = prefs.getDouble(_kReaderWidth) ?? 720.0;
      _themeMode = _themeModeFromString(prefs.getString(_kThemeMode));
    } catch (error) {
      _lastError = '读取本地数据失败：$error';
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kFeeds,
      jsonEncode(_feeds.map((Feed f) => f.toJson()).toList()),
    );
    final List<Article> trimmed = _sorted(List<Article>.of(_articles))
        .take(_maxArticles)
        .toList();
    await prefs.setString(
      _kArticles,
      jsonEncode(trimmed.map((Article a) => a.toJson()).toList()),
    );
    await prefs.setString(
      _kDeleted,
      jsonEncode(_deletedFeeds.map((DeletedFeed d) => d.toJson()).toList()),
    );
    await prefs.setString(_kStateTs, jsonEncode(_stateTimestamps));
    if (_webdavUrl != null) {
      await prefs.setString(_kWebdavUrl, _webdavUrl!);
    }
    if (_webdavUser != null) {
      await prefs.setString(_kWebdavUser, _webdavUser!);
    }
    if (_webdavPassword != null) {
      await prefs.setString(_kWebdavPass, _webdavPassword!);
    }
    await prefs.setDouble(_kReaderFont, _readerFontScale);
    await prefs.setDouble(_kReaderLine, _readerLineHeight);
    await prefs.setDouble(_kReaderWidth, _readerMaxWidth);
    await prefs.setString(_kThemeMode, _themeMode.name);
  }

  /// 添加订阅：先抓取验证，成功才入库。
  Future<void> addFeed(String url, {String? group}) async {
    final String normalized = _normalize(url);
    if (normalized.isEmpty) {
      _lastError = '请输入订阅地址';
      notifyListeners();
      return;
    }
    if (_feeds.any((Feed f) => f.url == normalized)) {
      _lastError = '这个订阅已经存在了';
      notifyListeners();
      return;
    }

    final Feed feed = Feed(
      id: stableHash(normalized),
      url: normalized,
      title: normalized,
      group: _normalizeGroup(group),
    );

    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final FetchedFeed fetched = await _fetcher.fetch(feed);
      feed.title =
          fetched.title.trim().isEmpty ? normalized : fetched.title.trim();
      feed.siteUrl = fetched.siteUrl;
      feed.lastFetched = DateTime.now();
      _feeds.add(feed);
      _mergeArticles(fetched.items);
    } catch (error) {
      _lastError = '订阅失败：${_describe(error)}';
    } finally {
      _loading = false;
      notifyListeners();
      await _persist();
    }
  }

  /// 从 OPML 批量导入订阅（逐个抓取验证，已存在的跳过）。
  Future<int> importFeeds(List<OpmlEntry> entries) async {
    if (entries.isEmpty) {
      return 0;
    }
    _loading = true;
    _lastError = null;
    notifyListeners();
    int added = 0;
    final List<String> failed = <String>[];
    for (final OpmlEntry entry in entries) {
      final String normalized = _normalize(entry.url);
      if (normalized.isEmpty || _feeds.any((Feed f) => f.url == normalized)) {
        continue;
      }
      final Feed feed = Feed(
        id: stableHash(normalized),
        url: normalized,
        title: entry.title,
        group: _normalizeGroup(entry.group),
      );
      try {
        final FetchedFeed fetched = await _fetcher.fetch(feed);
        feed.title =
            fetched.title.trim().isEmpty ? entry.title : fetched.title.trim();
        feed.siteUrl = fetched.siteUrl;
        feed.lastFetched = DateTime.now();
        _feeds.add(feed);
        _mergeArticles(fetched.items);
        added++;
      } catch (_) {
        failed.add(entry.title);
      }
    }
    _loading = false;
    _lastError =
        failed.isEmpty ? null : '${failed.length} 个源导入失败：${failed.join('、')}';
    notifyListeners();
    await _persist();
    return added;
  }

  Future<void> refreshAll() async {
    if (_feeds.isEmpty) {
      return;
    }
    _loading = true;
    _lastError = null;
    notifyListeners();
    final List<String> failed = <String>[];
    for (final Feed feed in _feeds) {
      try {
        final FetchedFeed fetched = await _fetcher.fetch(feed);
        if (fetched.title.trim().isNotEmpty) {
          feed.title = fetched.title.trim();
        }
        feed.siteUrl = fetched.siteUrl ?? feed.siteUrl;
        feed.lastFetched = DateTime.now();
        _mergeArticles(fetched.items);
      } catch (_) {
        failed.add(feed.title);
      }
    }
    _loading = false;
    _lastError = failed.isEmpty ? null : '刷新失败：${failed.join('、')}';
    notifyListeners();
    await _persist();
  }

  void removeFeed(Feed feed) {
    _feeds.removeWhere((Feed f) => f.id == feed.id);
    _articles.removeWhere((Article a) => a.feedId == feed.id);
    _deletedFeeds.removeWhere((DeletedFeed d) => d.id == feed.id);
    _deletedFeeds.add(
      DeletedFeed(id: feed.id, url: feed.url, deletedAt: DateTime.now()),
    );
    notifyListeners();
    _persist();
  }

  /// 合并新抓到的文章，保留已有的已读 / 收藏状态。
  void _mergeArticles(List<Article> incoming) {
    for (final Article article in incoming) {
      final int index = _articles.indexWhere((Article a) => a.id == article.id);
      if (index == -1) {
        _articles.add(article);
      } else {
        final Article existing = _articles[index];
        article
          ..read = existing.read
          ..starred = existing.starred;
        _articles[index] = article;
      }
    }
  }

  void setRead(Article article, bool value) {
    final Article target = _find(article);
    target.read = value;
    _stateTimestamps[target.id] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _persist();
  }

  void toggleStar(Article article) {
    final Article target = _find(article);
    target.starred = !target.starred;
    _stateTimestamps[target.id] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _persist();
  }

  void markAllRead() {
    for (final Article article in _articles) {
      article.read = true;
    }
    notifyListeners();
    _persist();
  }

  Future<void> saveWebDav({
    required String url,
    required String user,
    required String password,
  }) async {
    _webdavUrl = url;
    _webdavUser = user;
    _webdavPassword = password;
    await _persist();
    notifyListeners();
  }

  /// 与坚果云 WebDAV 做一次双向同步（LWW + 删除墓碑）。
  Future<String> syncNow() async {
    if (!webdavConfigured) {
      return '请先配置 WebDAV';
    }
    final WebDavClient client = WebDavClient(
      baseUrl: _webdavUrl!,
      username: _webdavUser!,
      password: _webdavPassword!,
    );

    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      await client.ensureDir('RSSReader');
      await client.ensureDir('RSSReader/sync');

      final String? remoteFeedsRaw =
          await client.readText('RSSReader/sync/feeds.json');
      final String? remoteStateRaw =
          await client.readText('RSSReader/sync/state.json');

      int added = 0;
      int removed = 0;
      int stateUpdated = 0;

      if (remoteFeedsRaw != null && remoteFeedsRaw.trim().isNotEmpty) {
        final Map<String, dynamic> doc =
            jsonDecode(remoteFeedsRaw) as Map<String, dynamic>;
        final List<dynamic> remoteDeleted =
            (doc['deleted'] as List<dynamic>?) ?? <dynamic>[];
        for (final dynamic raw in remoteDeleted) {
          final DeletedFeed tombstone =
              DeletedFeed.fromJson(raw as Map<String, dynamic>);
          _deletedFeeds.removeWhere(
            (DeletedFeed d) => d.id == tombstone.id,
          );
          _deletedFeeds.add(tombstone);
          final int index =
              _feeds.indexWhere((Feed f) => f.id == tombstone.id);
          if (index != -1 &&
              !tombstone.deletedAt.isBefore(_feeds[index].updatedAt)) {
            _feeds.removeAt(index);
            _articles.removeWhere(
              (Article a) => a.feedId == tombstone.id,
            );
            removed++;
          }
        }
        final List<dynamic> remoteFeeds =
            (doc['feeds'] as List<dynamic>?) ?? <dynamic>[];
        for (final dynamic raw in remoteFeeds) {
          final Feed incoming = Feed.fromJson(raw as Map<String, dynamic>);
          final int tombIndex = _deletedFeeds.indexWhere(
            (DeletedFeed d) => d.id == incoming.id,
          );
          if (tombIndex != -1) {
            if (!_deletedFeeds[tombIndex].deletedAt
                .isBefore(incoming.updatedAt)) {
              continue;
            }
            _deletedFeeds.removeAt(tombIndex);
          }
          final int index =
              _feeds.indexWhere((Feed f) => f.id == incoming.id);
          if (index == -1) {
            _feeds.add(incoming);
            added++;
          } else if (incoming.updatedAt.isAfter(_feeds[index].updatedAt)) {
            _feeds[index]
              ..title = incoming.title
              ..siteUrl = incoming.siteUrl
              ..group = incoming.group
              ..updatedAt = incoming.updatedAt;
          }
        }
      }

      if (remoteStateRaw != null && remoteStateRaw.trim().isNotEmpty) {
        final Map<String, dynamic> doc =
            jsonDecode(remoteStateRaw) as Map<String, dynamic>;
        final Map<String, dynamic> states =
            (doc['states'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        states.forEach((String articleId, dynamic raw) {
          final Map<String, dynamic> state = raw as Map<String, dynamic>;
          final int remoteTs = (state['updatedAt'] as num?)?.toInt() ?? 0;
          final int localTs = _stateTimestamps[articleId] ?? 0;
          if (remoteTs > localTs) {
            final int index =
                _articles.indexWhere((Article a) => a.id == articleId);
            if (index != -1) {
              _articles[index]
                ..read = (state['read'] as bool?) ?? false
                ..starred = (state['starred'] as bool?) ?? false;
            }
            _stateTimestamps[articleId] = remoteTs;
            stateUpdated++;
          }
        });
      }

      await client.writeText(
        'RSSReader/sync/feeds.json',
        jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'updatedAt': DateTime.now().toIso8601String(),
          'feeds': _feeds.map((Feed f) => f.toJson()).toList(),
          'deleted': _deletedFeeds.map((DeletedFeed d) => d.toJson()).toList(),
        }),
      );
      await client.writeText(
        'RSSReader/sync/state.json',
        jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'updatedAt': DateTime.now().toIso8601String(),
          'states': <String, dynamic>{
            for (final Article a in _articles)
              a.id: <String, dynamic>{
                'read': a.read,
                'starred': a.starred,
                'updatedAt': _stateTimestamps[a.id] ?? 0,
              },
          },
        }),
      );
      await client.writeText(
        'RSSReader/sync/meta.json',
        jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'lastSyncAt': DateTime.now().toIso8601String(),
        }),
      );

      await _persist();
      return '同步完成：新增 $added、移除 $removed、状态更新 $stateUpdated';
    } catch (error) {
      _lastError = '同步失败：${_describe(error)}';
      return _lastError!;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveReaderPrefs({
    double? fontScale,
    double? lineHeight,
    double? maxWidth,
  }) async {
    if (fontScale != null) {
      _readerFontScale = fontScale;
    }
    if (lineHeight != null) {
      _readerLineHeight = lineHeight;
    }
    if (maxWidth != null) {
      _readerMaxWidth = maxWidth;
    }
    await _persist();
    notifyListeners();
  }

  /// 抓取原文页面并提取正文（订阅源只给摘要时使用）。
  Future<bool> fetchFullText(Article article) async {
    final String? link = article.link;
    if (link == null || link.isEmpty) {
      _lastError = '这篇文章没有原文链接';
      notifyListeners();
      return false;
    }
    if (_fetchingFullText) {
      return false;
    }
    _fetchingFullText = true;
    _lastError = null;
    notifyListeners();
    try {
      final String? html = await _readable.extractMainHtml(link);
      if (html == null || html.isEmpty) {
        _lastError = '没能从原文页面提取到正文';
        return false;
      }
      _find(article).updateBody(html);
      await _persist();
      return true;
    } catch (error) {
      _lastError = '抓取原文失败：${_describe(error)}';
      return false;
    } finally {
      _fetchingFullText = false;
      notifyListeners();
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _persist();
    notifyListeners();
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setFeedGroup(Feed feed, String group) {
    final String normalized = _normalizeGroup(group);
    final int index = _feeds.indexWhere((Feed f) => f.id == feed.id);
    if (index == -1) {
      feed
        ..group = normalized
        ..updatedAt = DateTime.now();
    } else {
      _feeds[index]
        ..group = normalized
        ..updatedAt = DateTime.now();
    }
    notifyListeners();
    _persist();
  }

  String _normalizeGroup(String? group) {
    final String value = (group ?? '').trim();
    return value.isEmpty ? Feed.defaultGroup : value;
  }

  Article _find(Article article) => _articles.firstWhere(
        (Article a) => a.id == article.id,
        orElse: () => article,
      );

  String _normalize(String url) {
    String value = url.trim();
    if (value.isEmpty) {
      return value;
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    return value;
  }

  String _describe(Object error) {
    if (error is DioException) {
      return '${error.type.name}${error.message == null ? '' : ' / ${error.message}'}';
    }
    return '$error';
  }
}
