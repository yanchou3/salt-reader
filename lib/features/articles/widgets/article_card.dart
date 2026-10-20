import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/glass.dart';
import '../../../data/models/article.dart';

/// 椒盐风格的圆角文章卡片：玻璃质感（半透明 + 高光描边）。
///
/// 列表可能有 300+ 条，这里刻意**不开实时模糊**（[GlassContainer.blur] 为 false）：
/// 每张卡都采样背景会让滚动明显掉帧，半透明底已经能得到玻璃观感。
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
    final BorderRadius radius = BorderRadius.circular(AppRadius.lg);

    return RepaintBoundary(
      child: GlassContainer(
        blur: false,
        borderRadius: radius,
        tintAlpha: GlassTokens.alphaCard,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md + 2,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: article.read
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.58)
                          : null,
                    ),
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
      ),
    );
  }
}
