import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/placeholder_empty.dart';
import '../../data/app_store.dart';
import '../../data/models/article.dart';
import '../../data/models/feed.dart';
import '../articles/article_reader_page.dart';
import '../articles/widgets/article_actions.dart';
import '../articles/widgets/article_card.dart';

/// 某个订阅源的全部文章。
class FeedArticlesPage extends StatefulWidget {
  const FeedArticlesPage({super.key, required this.feed});

  final Feed feed;

  @override
  State<FeedArticlesPage> createState() => _FeedArticlesPageState();
}

class _FeedArticlesPageState extends State<FeedArticlesPage> {
  bool _showAll = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (BuildContext context, Widget? child) {
        final AppStore store = AppStore.instance;
        final ThemeData theme = Theme.of(context);
        final List<Article> all = store.articlesOfFeed(widget.feed.id);
        final int unread = all.where((Article a) => !a.read).length;
        final List<Article> articles =
            _showAll ? all : all.where((Article a) => !a.read).toList();

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: GlassAppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: '返回',
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.feed.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$unread 篇未读 · 共 ${all.length} 篇',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                onPressed: store.loading ? null : () => store.refreshAll(),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新',
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                // 正文延伸到玻璃 AppBar 下方，这里补回被遮住的高度。
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  MediaQuery.of(context).padding.top +
                      kToolbarHeight +
                      AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(value: false, label: Text('未读')),
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
              Expanded(child: _content(context, store, articles, all)),
            ],
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    AppStore store,
    List<Article> articles,
    List<Article> all,
  ) {
    if (all.isEmpty) {
      return const PlaceholderEmpty(
        icon: Icons.article_outlined,
        title: '这个源还没有文章',
        description: '下拉刷新试试，或等下一次更新。',
      );
    }
    if (articles.isEmpty) {
      return RefreshIndicator(
        onRefresh: store.refreshAll,
        child: ListView(
          children: const <Widget>[
            SizedBox(height: 120),
            PlaceholderEmpty(
              icon: Icons.check_circle_outline_rounded,
              title: '都读完了',
              description: '这个源没有未读文章，下拉可刷新。',
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
          0,
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
}
