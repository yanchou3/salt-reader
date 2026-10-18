import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/models/article.dart';

/// 椒盐风格的圆角文章卡片：大留白、柔阴影、克制的元信息。
class ArticleCard extends StatelessWidget {
  const ArticleCard({
    super.key,
    required this.article,
    this.onTap,
    this.onLongPress,
  });

  final Article article;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final String summary = article.summary;

    return RepaintBoundary(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? <Color>[
                        AppColors.darkSurface,
                        AppColors.darkSurfaceAlt,
                      ]
                    : <Color>[
                        AppColors.lightSurface,
                        const Color(0xFFFBFBFC),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? AppColors.darkOutline
                    : AppColors.lightOutline,
              ),
              boxShadow: isDark ? AppShadows.softDark : AppShadows.soft,
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (!article.read)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: AppSpacing.sm),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        article.feedTitle,
                        style: theme.textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text('·', style: TextStyle(color: secondary)),
                    ),
                    Text(
                      relativeTime(article.published),
                      style: theme.textTheme.labelSmall,
                    ),
                    if (article.starred) ...<Widget>[
                      const Spacer(),
                      const Icon(
                        Icons.bookmark_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  article.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (summary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
