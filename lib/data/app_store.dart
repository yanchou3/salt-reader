import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';
import '../core/theme/reader_fonts.dart';
import '../services/feed_fetcher.dart';
import '../services/font_library.dart';
import '../services/opml_service.dart';
import '../services/readable_service.dart';
import '../services/updater.dart';
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
  static const String _kReaderFontId = 'reader_font_id';
  static const String _kReaderCustomFonts = 'reader_custom_fonts';
  static const String _kThemeMode = 'theme_mode';
  static const String _kAutoFullText = 'auto_full_text';
  static const String _kAutoCheckUpdate = 'auto_check_update';
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
  ReaderFont _readerFont = ReaderFont.system;
  final List<ReaderFont> _customFonts = <ReaderFont>[];
  String? _loadingFontId;
  double _fontProgress = 0;
  String? _fontSource;
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoFetchFullText = true;

  bool _autoCheckUpdate = true;
  UpdateInfo? _availableUpdate;
  bool _checkingUpdate = false;
  String? _updateError;

  bool _loading = false;
  String? _lastError;
  bool _fetchingFullText = false;

  /// 派生数据（排序 / 筛选 / 分组 / 计数）的记忆化缓存。
  /// 每次数据变更自增 [_revision]，所有 build 共用同一份结果，避免每帧重算。
  int _revision = 0;

  void _bump() {
    _revision++;
    notifyListeners();
  }

  int get revision => _revision;

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

  /// 正文字体。
  ReaderFont get readerFont => _readerFont;

  /// 用户本地导入的字体。
  List<ReaderFont> get customFonts => List<ReaderFont>.unmodifiable(_customFonts);

  /// 正在下载/注册的字体 id（用于 UI 展示进度）。
  String? get loadingFontId => _loadingFontId;

  /// 当前字体加载进度 0..1。
  double get fontProgress => _fontProgress;

  /// 当前字体正在从哪个镜像下载（如「清华镜像」）。
  String? get fontSource => _fontSource;

  /// 实际可用的字体族名：字体没注册好时返回 null（回退系统字体）。
  String? get activeFontFamily => FontLibrary.instance.isRegistered(_readerFont)
      ? _readerFont.family
      : null;
  ThemeMode get themeMode => _themeMode;

  /// 打开文章时，若正文过短是否自动抓取原文全文。
  bool get autoFetchFullText => _autoFetchFullText;

  /// 启动后是否自动静默检查新版本。
  bool get autoCheckUpdate => _autoCheckUpdate;

  /// 最近一次检查到的新版本（已是最新或尚未检查时为 null）。
  UpdateInfo? get availableUpdate => _availableUpdate;

  /// 是否正在检查更新。
  bool get checkingUpdate => _checkingUpdate;

  /// 最近一次「手动检查」的失败原因。
  String? get updateError => _updateError;

  // ---- 派生数据记忆化 ----
  int _derivedRevision = -1;
  List<Article> _cachedAll = const <Article>[];
  List<Article> _cachedUnread = const <Article>[];
  List<Article> _cachedStarred = const <Article>[];
  List<String> _cachedGroups = const <String>[];
  Map<String, Feed> _feedById = const <String, Feed>{};
  Map<String, List<Article>> _articlesByFeed = const <String, List<Article>>{};
  Map<String, int> _unreadByFeed = const <String, int>{};

  /// 仅在数据真正变化时重算一次所有派生列表。
  void _ensureDerived() {
    if (_derivedRevision == _revision) {
      return;
    }
    _derivedRevision = _revision;

    final List<Article> sorted = _sorted(List<Article>.of(_articles));
    final List<Article> unread = <Article>[];
    final List<Article> starred = <Article>[];
    final Map<String, List<Article>> byFeed =
        <String, List<Article>>{};
    final Map<String, int> unreadCount = <String, int>{};
    for (final Article a in sorted) {
      if (!a.read) {
        unread.add(a);
        unreadCount[a.feedId] = (unreadCount[a.feedId] ?? 0) + 1;
      }
      if (a.starred) {
        starred.add(a);
      }
      (byFeed[a.feedId] ??= <Article>[]).add(a);
    }
    _cachedAll = sorted;
    _cachedUnread = unread;
    _cachedStarred = starred;
    _articlesByFeed = byFeed;
    _unreadByFeed = unreadCount;
    _feedById = <String, Feed>{
      for (final Feed f in _feeds) f.id: f,
    };

    final Set<String> names = _feeds.map((Feed f) => f.group).toSet();
    final List<String> groups = names.toList()..sort();
    if (groups.remove(Feed.defaultGroup)) {
      groups.insert(0, Feed.defaultGroup);
    }
    _cachedGroups = groups;
  }

  /// 分组名列表（未分组优先，其余按名称排序）。
  List<String> get groups {
    _ensureDerived();
    return _cachedGroups;
  }

  /// 某篇文章所属订阅源的分组名。
  String groupOfFeed(String feedId) {
    _ensureDerived();
    return _feedById[feedId]?.group ?? Feed.defaultGroup;
  }

  List<Article> get unreadArticles {
    _ensureDerived();
    return _cachedUnread;
  }

  /// 某个订阅源的全部文章（按时间倒序）。
  List<Article> articlesOfFeed(String feedId) {
    _ensureDerived();
    return _articlesByFeed[feedId] ?? const <Article>[];
  }

  /// 某个订阅源的未读数。
  int unreadCountOfFeed(String feedId) {
    _ensureDerived();
    return _unreadByFeed[feedId] ?? 0;
  }

  List<Article> get allArticles {
    _ensureDerived();
    return _cachedAll;
  }

  List<Article> get starredArticles {
    _ensureDerived();
    return _cachedStarred;
  }

  int get unreadCount => unreadArticles.length;

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
      final String? customRaw = prefs.getString(_kReaderCustomFonts);
      if (customRaw != null) {
        final List<dynamic> list = jsonDecode(customRaw) as List<dynamic>;
        _customFonts
          ..clear()
          ..addAll(
            list.map(
              (dynamic e) => ReaderFont.fromJson(e as Map<String, dynamic>),
            ),
          );
      }
      _readerFont = ReaderFont.byId(
        prefs.getString(_kReaderFontId),
        _customFonts,
      );
      _themeMode = _themeModeFromString(prefs.getString(_kThemeMode));
      _autoFetchFullText = prefs.getBool(_kAutoFullText) ?? true;
      _autoCheckUpdate = prefs.getBool(_kAutoCheckUpdate) ?? true;
    } catch (error) {
      _lastError = '读取本地数据失败：${_describe(error)}';
    }
    _bump();
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
    await prefs.setString(_kReaderFontId, _readerFont.id);
    await prefs.setString(
      _kReaderCustomFonts,
      jsonEncode(_customFonts.map((ReaderFont f) => f.toJson()).toList()),
    );
    await prefs.setString(_kThemeMode, _themeMode.name);
    await prefs.setBool(_kAutoFullText, _autoFetchFullText);
    await prefs.setBool(_kAutoCheckUpdate, _autoCheckUpdate);
  }

  /// 添加订阅：先抓取验证，成功才入库。
  Future<void> addFeed(String url, {String? group}) async {
    final String normalized = _normalize(url);
    if (normalized.isEmpty) {
      _lastError = '请输入订阅地址';
      _bump();
      return;
    }
    if (_feeds.any((Feed f) => f.url == normalized)) {
      _lastError = '这个订阅已经存在了';
      _bump();
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
    _bump();
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
      _bump();
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
    _bump();
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
    _bump();
    await _persist();
    return added;
  }

  Future<void> refreshAll() async {
    if (_feeds.isEmpty) {
      return;
    }
    _loading = true;
    _lastError = null;
    _bump();
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
    _bump();
    await _persist();
  }

  void removeFeed(Feed feed) {
    _feeds.removeWhere((Feed f) => f.id == feed.id);
    _articles.removeWhere((Article a) => a.feedId == feed.id);
    _deletedFeeds.removeWhere((DeletedFeed d) => d.id == feed.id);
    _deletedFeeds.add(
      DeletedFeed(id: feed.id, url: feed.url, deletedAt: DateTime.now()),
    );
    _bump();
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
    _bump();
    _persist();
  }

  void toggleStar(Article article) {
    final Article target = _find(article);
    target.starred = !target.starred;
    _stateTimestamps[target.id] = DateTime.now().millisecondsSinceEpoch;
    _bump();
    _persist();
  }

  void markAllRead() {
    for (final Article article in _articles) {
      article.read = true;
    }
    _bump();
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
    _bump();
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
    _bump();
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
      _bump();
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
    _bump();
  }

  /// 切换正文字体：需要时下载并注册，成功后写入偏好。
  Future<bool> selectFont(ReaderFont font) async {
    _readerFont = font;
    _loadingFontId = font.id;
    _fontProgress = 0;
    _fontSource = null;
    _lastError = null;
    _bump();

    bool ok = true;
    try {
      ok = await FontLibrary.instance.ensure(
        font,
        onProgress: (int received, int total, String source) {
          _fontSource = source;
          _fontProgress = total > 0 ? received / total : 0;
          _bump();
        },
      );
    } catch (error) {
      ok = false;
      _lastError = error is FontLibraryException
          ? error.message
          : '字体加载失败：$error';
    }

    _loadingFontId = null;
    _fontProgress = 0;
    _fontSource = null;
    if (!ok) {
      _lastError ??= '字体加载失败，已回退到系统默认字体';
      _readerFont = ReaderFont.system;
    }
    await _persist();
    _bump();
    return ok;
  }

  /// 导入本地字体文件并立即启用。
  Future<bool> addLocalFont(Uint8List bytes, String label) async {
    try {
      final ReaderFont font = await FontLibrary.instance.importBytes(
        bytes,
        label,
      );
      _customFonts.add(font);
      return await selectFont(font);
    } catch (error) {
      _lastError = '导入字体失败：${_describe(error)}';
      _bump();
      return false;
    }
  }

  /// 删除本地导入的字体；若正在使用则回退到系统默认。
  Future<void> removeLocalFont(ReaderFont font) async {
    await FontLibrary.instance.remove(font);
    _customFonts.removeWhere((ReaderFont f) => f.id == font.id);
    if (_readerFont.id == font.id) {
      _readerFont = ReaderFont.system;
    }
    await _persist();
    _bump();
  }

  /// 启动时把上次选中的字体准备好（失败则静默回退）。
  Future<void> ensureReaderFontReady() async {
    final ReaderFont font = _readerFont;
    if (font.isSystem || FontLibrary.instance.isRegistered(font)) {
      return;
    }
    bool ok = true;
    try {
      ok = await FontLibrary.instance.ensure(font);
    } catch (error) {
      ok = false;
      _lastError = error is FontLibraryException
          ? error.message
          : '字体加载失败：$error';
    }
    if (!ok) {
      _readerFont = ReaderFont.system;
      await _persist();
    }
    _bump();
  }

  /// 抓取原文页面并提取正文（订阅源只给摘要时使用）。
  Future<bool> fetchFullText(Article article) async {
    final String? link = article.link;
    if (link == null || link.isEmpty) {
      _lastError = '这篇文章没有原文链接';
      _bump();
      return false;
    }
    if (_fetchingFullText) {
      return false;
    }
    _fetchingFullText = true;
    _lastError = null;
    _bump();
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
      _bump();
    }
  }

  Future<void> saveAutoFetchFullText(bool value) async {
    _autoFetchFullText = value;
    await _persist();
    _bump();
  }

  Future<void> saveAutoCheckUpdate(bool value) async {
    _autoCheckUpdate = value;
    await _persist();
    _bump();
    if (value) {
      await checkForUpdate(silent: true);
    }
  }

  /// 检查新版本，结果缓存在 [availableUpdate] 供设置页与「关于」复用。
  ///
  /// [silent] 用于启动后的静默检查：失败不记录 [updateError]，不打扰用户。
  Future<UpdateInfo?> checkForUpdate({bool silent = false}) async {
    if (_checkingUpdate) {
      return _availableUpdate;
    }
    _checkingUpdate = true;
    _updateError = null;
    _bump();
    try {
      final UpdateInfo? info =
          await Updater.instance.checkForUpdate(AppInfo.version);
      _availableUpdate = info;
      return info;
    } catch (error) {
      if (!silent) {
        _updateError = _describe(error);
      }
      return null;
    } finally {
      _checkingUpdate = false;
      _bump();
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _persist();
    _bump();
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
    _bump();
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

  /// 把异常翻译成用户能看懂的提示（原来的 DioExceptionType 名对用户没意义）。
  String _describe(Object error) {
    if (error is FormatException) {
      return error.message;
    }
    if (error is DioException) {
      final int? code = error.response?.statusCode;
      switch (error.type) {
        case DioExceptionType.badResponse:
          if (code == 404) {
            return '地址不存在（HTTP 404），请检查订阅地址是否写错';
          }
          if (code == 401 || code == 403) {
            return '站点拒绝访问（HTTP $code），可能需要登录或有反爬限制';
          }
          if (code == 429) {
            return '请求太频繁（HTTP 429），稍后再试';
          }
          if (code != null && code >= 500) {
            return '站点服务器出错（HTTP $code），与本站无关，稍后再试';
          }
          return code == null ? '服务器返回异常' : '服务器返回异常（HTTP $code）';
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return '连接超时，请检查网络或该站点是否可访问';
        case DioExceptionType.connectionError:
          return '连不上这个站点，请检查网络或域名是否正确';
        case DioExceptionType.badCertificate:
          return 'HTTPS 证书校验失败，该站点的证书不受信任';
        case DioExceptionType.cancel:
          return '请求已取消';
        case DioExceptionType.unknown:
          break;
      }
      final Object? inner = error.error;
      if (inner is SocketException) {
        return '连不上这个站点：${inner.osError?.message ?? inner.message}';
      }
      return error.message ?? '网络请求失败';
    }
    if (error is PlatformException) {
      // 插件的异常原文里带着几十行 Java 堆栈，界面上只给一句结论。
      return '本机读写失败（${error.code}），请重启应用；'
          '若反复出现，请更新到最新版本';
    }
    // 其它异常兜底：压成一行、截断，避免把堆栈直接糊到界面上。
    final String text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) {
      return '未知错误';
    }
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
