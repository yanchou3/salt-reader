import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatting.dart';
import '../../core/utils/html_utils.dart';
import '../../data/app_store.dart';
import '../../data/models/article.dart';

/// 文章阅读页：椒盐风格的正文排版（可调字号 / 行距 / 栏宽）。
class ArticleReaderPage extends StatefulWidget {
  const ArticleReaderPage({super.key, required this.article});

  final Article article;

  @override
  State<ArticleReaderPage> createState() => _ArticleReaderPageState();
}

class _ArticleReaderPageState extends State<ArticleReaderPage> {
  String? _renderedSource;
  String? _renderedHtml;

  /// 已解析的正文组件缓存：只要正文 / 链接 / 排版不变就复用，
  /// 避免收藏、抓取进度等无关通知触发 HtmlWidget 重新解析。
  String? _htmlCacheKey;
  Widget? _cachedHtml;

  Widget _htmlWidget(String body, String? baseUrl, TextStyle style) {
    final String key = '${body.hashCode}|${baseUrl ?? ''}'
        '|${style.fontSize}|${style.height}';
    if (_htmlCacheKey == key && _cachedHtml != null) {
      return _cachedHtml!;
    }
    final Widget widget =
        HtmlWidget(_renderBody(body, baseUrl), textStyle: style);
    _htmlCacheKey = key;
    _cachedHtml = widget;
    return widget;
  }

  /// 渲染前把相对路径补全为绝对路径（图片 / 链接），并按 body 做缓存。
  String _renderBody(String body, String? baseUrl) {
    if (_renderedSource == body && _renderedHtml != null) {
      return _renderedHtml!;
    }
    _renderedSource = body;
    _renderedHtml = resolveRelativeUrls(body, baseUrl);
    return _renderedHtml!;
  }

  @override
  void initState() {
    super.initState();
    // 打开即标记已读；放到首帧之后，避免在构建期间触发通知。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final AppStore store = AppStore.instance;
      if (!widget.article.read) {
        store.setRead(widget.article, true);
      }
      // 默认自动抓取全文：正文过短且有原文链接时。
      final String? link = widget.article.link;
      if (store.autoFetchFullText &&
          link != null &&
          link.isNotEmpty &&
          widget.article.summary.length < 400) {
        store.fetchFullText(widget.article);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (BuildContext context, Widget? child) {
        final AppStore store = AppStore.instance;
        final ThemeData theme = Theme.of(context);
        final bool isDark = theme.brightness == Brightness.dark;
        final Color subtle = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
        final Article article = widget.article;
        final String body = article.body.trim();
        final TextStyle bodyStyle =
            (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
          fontSize: 16 * store.readerFontScale,
          height: store.readerLineHeight,
        );

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: '返回',
            ),
            title: Text(
              article.feedTitle,
              style: theme.textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: true,
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  article.starred
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 22,
                ),
                color: article.starred ? AppColors.accent : null,
                onPressed: () => AppStore.instance.toggleStar(article),
                tooltip: article.starred ? '取消收藏' : '收藏',
              ),
              IconButton(
                icon: const Icon(Icons.text_format_rounded, size: 22),
                onPressed: () => _showQuickTypeSettings(context, store),
                tooltip: '字号与行距',
              ),
              if ((article.link ?? '').isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  onPressed: () => _openInBrowser(context, article.link!),
                  tooltip: '在浏览器打开',
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: store.readerMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(article.title, style: theme.textTheme.displaySmall),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
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
                            child: Text('·', style: TextStyle(color: subtle)),
                          ),
                          Text(
                            relativeTime(article.published),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Divider(color: theme.colorScheme.outline),
                      const SizedBox(height: AppSpacing.xl),
                      if (_shouldOfferFullText(article))
                        _FullTextHint(
                          fetching: store.fetchingFullText,
                          onFetch: () => _fetchFull(store, article),
                          onOpen: () => _openInBrowser(context, article.link!),
                        ),
                      if (body.isEmpty)
                        Text(
                          '这个订阅源没有提供正文内容。',
                          style:
                              theme.textTheme.bodyMedium?.copyWith(color: subtle),
                        )
                      else
                        _htmlWidget(body, article.link, bodyStyle),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 正文太短（多半只是摘要）且有原文链接时，提示抓取全文。
  bool _shouldOfferFullText(Article article) {
    final String? link = article.link;
    if (link == null || link.isEmpty) {
      return false;
    }
    return article.summary.length < 400;
  }

  Future<void> _fetchFull(AppStore store, Article article) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await store.fetchFullText(article);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '已抓取全文' : (store.lastError ?? '抓取失败')),
      ),
    );
  }

  /// 用系统浏览器打开原文。
  Future<void> _openInBrowser(BuildContext context, String url) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('没能打开浏览器')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('打开失败：$error')));
    }
  }

  /// 阅读页内的快捷排版调整。
  void _showQuickTypeSettings(BuildContext context, AppStore store) {
    double fontScale = store.readerFontScale;
    double lineHeight = store.readerLineHeight;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('排版', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                _prefSlider(
                  '字号',
                  fontScale,
                  0.8,
                  1.6,
                  (double v) => setLocal(() => fontScale = v),
                ),
                _prefSlider(
                  '行距',
                  lineHeight,
                  1.3,
                  2.2,
                  (double v) => setLocal(() => lineHeight = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      store.saveReaderPrefs(
                        fontScale: fontScale,
                        lineHeight: lineHeight,
                      );
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _prefSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label  ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13),
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

/// 只拿到摘要时的提示条：抓取全文 / 在浏览器打开。
class _FullTextHint extends StatelessWidget {
  const _FullTextHint({
    required this.fetching,
    required this.onFetch,
    required this.onOpen,
  });

  final bool fetching;
  final VoidCallback onFetch;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('这个订阅源只提供了摘要。', style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '可以抓取原文页面的正文，或者直接用浏览器打开。',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              FilledButton.tonal(
                onPressed: fetching ? null : onFetch,
                child: Text(fetching ? '抓取中…' : '抓取全文'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onOpen,
                child: const Text('在浏览器打开'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
