import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/placeholder_empty.dart';
import '../../data/app_store.dart';
import '../../data/models/article.dart';
import 'article_reader_page.dart';
import 'widgets/article_actions.dart';
import 'widgets/article_card.dart';

/// 未读文章列表页：支持按分组筛选与下拉刷新。
class ArticleListPage extends StatefulWidget {
  const ArticleListPage({super.key});

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  static const String _allFilter = '全部';
  String _filter = _allFilter;
  bool _searching = false;
  String _query = '';
  bool _showAll = false;

  /// 筛选 / 搜索结果的记忆化缓存：仅在条件或数据版本变化时重算，
  /// 避免每帧对列表做 where/toList（搜索时还会扫描正文）。
  int _cacheRevision = -1;
  String _cacheKey = '';
  List<Article> _cachedArticles = const <Article>[];

  List<Article> _filtered(AppStore store, String activeFilter, String query) {
    final String key = '$_showAll\u0000$activeFilter\u0000$query';
    if (_cacheRevision == store.revision && _cacheKey == key) {
      return _cachedArticles;
    }
    final List<Article> source =
        _showAll ? store.allArticles : store.unreadArticles;
    final List<Article> result;
    if (query.isEmpty) {
      result = activeFilter == _allFilter
          ? source
          : source
              .where(
                (Article a) => store.groupOfFeed(a.feedId) == activeFilter,
              )
              .toList();
    } else {
      result = store.allArticles
          .where(
            (Article a) =>
                a.title.toLowerCase().contains(query) ||
                a.body.toLowerCase().contains(query),
          )
          .toList();
    }
    _cacheRevision = store.revision;
    _cacheKey = key;
    _cachedArticles = result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (BuildContext context, Widget? child) {
        final AppStore store = AppStore.instance;
        final ThemeData theme = Theme.of(context);
        final List<String> filters = <String>[_allFilter, ...store.groups];
        final String activeFilter =
            filters.contains(_filter) ? _filter : _allFilter;
        final String query = _query.trim().toLowerCase();
        final List<Article> articles = _filtered(store, activeFilter, query);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('未读', style: theme.textTheme.displaySmall),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              store.loading
                                  ? '正在刷新…'
                                  : query.isNotEmpty
                                      ? '搜索到 ${articles.length} 篇'
                                      : _showAll
                                          ? '共 ${articles.length} 篇'
                                          : '${articles.length} 篇待读',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) {
                            _query = '';
                          }
                        }),
                        icon: Icon(
                          _searching
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                        ),
                        tooltip: _searching ? '关闭搜索' : '搜索',
                      ),
                      if (articles.isNotEmpty)
                        IconButton(
                          onPressed: store.markAllRead,
                          icon: const Icon(Icons.done_all_rounded),
                          tooltip: '全部已读',
                        ),
                      IconButton(
                        onPressed: store.loading || !store.hasFeeds
                            ? null
                            : () => store.refreshAll(),
                        icon: store.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        tooltip: '刷新',
                      ),
                    ],
                  ),
                ),
                if (!_searching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<bool>(
                        segments: const <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('未读'),
                          ),
                          ButtonSegment<bool>(value: true, label: Text('全部')),
                        ],
                        selected: <bool>{_showAll},
                        onSelectionChanged: (Set<bool> selection) =>
                            setState(() => _showAll = selection.first),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: TextField(
                      autofocus: true,
                      onChanged: (String value) =>
                          setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: '搜索标题或正文',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                if (!_searching && filters.length > 1)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: filters.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (BuildContext context, int index) {
                        final String name = filters[index];
                        final bool selected = name == activeFilter;
                        return ChoiceChip(
                          label: Text(name),
                          selected: selected,
                          onSelected: (_) => setState(() => _filter = name),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected
                                ? AppColors.accent
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                if (store.lastError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        store.lastError!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.accent),
                      ),
                    ),
                  ),
                Expanded(
                  child: _content(
                    context,
                    store,
                    articles,
                    query.isNotEmpty,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    AppStore store,
    List<Article> articles,
    bool searchActive,
  ) {
    if (!store.hasFeeds) {
      return const PlaceholderEmpty(
        icon: Icons.rss_feed,
        title: '还没有订阅源',
        description: '切到「订阅」页，添加一个 RSS 地址就能开始阅读。',
      );
    }
    // 首次刷新且列表为空时用骨架屏占位，避免直接闪出「都读完了」。
    if (articles.isEmpty && store.loading) {
      return _skeletonList();
    }
    if (articles.isEmpty) {
      return RefreshIndicator(
        onRefresh: store.refreshAll,
        child: ListView(
          children: <Widget>[
            const SizedBox(height: 120),
            PlaceholderEmpty(
              icon: searchActive
                  ? Icons.search_off_rounded
                  : Icons.check_circle_outline_rounded,
              title: searchActive ? '没有匹配的文章' : '都读完了',
              description: searchActive
                  ? '换个关键词再试试。'
                  : '当前没有未读文章，下拉可刷新。',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: store.refreshAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.navBottom,
        ),
        itemCount: articles.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          final Article article = articles[index];
          return ArticleCard(
            article: article,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ArticleReaderPage(article: article),
              ),
            ),
            onLongPress: () => showArticleActions(context, article),
          );
        },
      ),
    );
  }

  Widget _skeletonList() {
    return _SkeletonPulse(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.navBottom,
        ),
        itemCount: 6,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) =>
            const _SkeletonCard(),
      ),
    );
  }
}

/// 一个卡片的加载骨架（结构与 ArticleCard 对齐）。
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
              .withValues(alpha: isDark ? 1 : 0.7),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md + 2,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SkeletonBar(width: 96, height: 10),
          SizedBox(height: AppSpacing.md),
          _SkeletonBar(width: double.infinity, height: 15),
          SizedBox(height: AppSpacing.sm),
          _SkeletonBar(width: 208, height: 15),
          SizedBox(height: AppSpacing.sm),
          _SkeletonBar(width: double.infinity, height: 12),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
            .withValues(alpha: isDark ? 0.9 : 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}

/// 让整块骨架共用一个呼吸动画，避免每个色块各起一个控制器。
class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({required this.child});

  final Widget child;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
