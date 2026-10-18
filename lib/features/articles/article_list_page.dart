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
        final List<Article> source =
            _showAll ? store.allArticles : store.unreadArticles;
        final List<Article> articles = query.isEmpty
            ? source
                .where(
                  (Article a) =>
                      activeFilter == _allFilter ||
                      store.groupOfFeed(a.feedId) == activeFilter,
                )
                .toList()
            : store.allArticles
                .where(
                  (Article a) =>
                      a.title.toLowerCase().contains(query) ||
                      a.body.toLowerCase().contains(query),
                )
                .toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
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
          AppSpacing.xxl,
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
}
