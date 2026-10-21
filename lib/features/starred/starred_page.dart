import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/widgets/placeholder_empty.dart';
import '../../core/widgets/smooth_wheel.dart';
import '../../data/app_store.dart';
import '../../data/models/article.dart';
import '../articles/article_reader_page.dart';
import '../articles/widgets/article_actions.dart';
import '../articles/widgets/article_card.dart';

/// 收藏 / 稍后读页。
class StarredPage extends StatelessWidget {
  const StarredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (BuildContext context, Widget? child) {
        final AppStore store = AppStore.instance;
        final ThemeData theme = Theme.of(context);
        final List<Article> starred = store.starredArticles;

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
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('收藏', style: theme.textTheme.displaySmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${starred.length} 篇',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: starred.isEmpty
                      ? const PlaceholderEmpty(
                          icon: Icons.bookmark_outline,
                          title: '暂无收藏',
                          description: '在阅读页点右上角的书签，就会收进这里，方便稍后细读。',
                        )
                      : SmoothWheelArea(
                          builder:
                              (
                                BuildContext context,
                                ScrollController controller,
                              ) => ListView.separated(
                                controller: controller,
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.lg,
                                  0,
                                  AppSpacing.lg,
                                  AppSpacing.navBottom,
                                ),
                                itemCount: starred.length,
                                separatorBuilder:
                                    (BuildContext context, int index) =>
                                        const SizedBox(height: AppSpacing.md),
                                itemBuilder: (BuildContext context, int index) {
                                  final Article article = starred[index];
                                  return ArticleCard(
                                    article: article,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ArticleReaderPage(
                                          article: article,
                                        ),
                                      ),
                                    ),
                                    onLongPress: () => showArticleActions(
                                      context,
                                      article,
                                    ),
                                  );
                                },
                              ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
