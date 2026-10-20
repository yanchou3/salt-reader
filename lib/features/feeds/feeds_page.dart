import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/placeholder_empty.dart';
import '../../data/app_store.dart';
import '../../data/models/feed.dart';
import 'feed_articles_page.dart';

/// 订阅管理页：按分组展示订阅源，可添加 / 删除 / 改分组 / 刷新。
class FeedsPage extends StatelessWidget {
  const FeedsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (BuildContext context, Widget? child) {
        final AppStore store = AppStore.instance;
        final ThemeData theme = Theme.of(context);

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
                    AppSpacing.lg,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('订阅', style: theme.textTheme.displaySmall),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              store.loading
                                  ? '正在刷新…'
                                  : '${store.feeds.length} 个订阅源 · ${store.groups.length} 个分组',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      if (store.hasFeeds)
                        IconButton(
                          onPressed:
                              store.loading ? null : () => store.refreshAll(),
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: '全部刷新',
                        ),
                      IconButton(
                        onPressed: () => _showAddFeedDialog(context),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: '添加订阅',
                      ),
                    ],
                  ),
                ),
                if (store.lastError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
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
                Expanded(child: _content(context, store)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, AppStore store) {
    if (store.feeds.isEmpty) {
      return PlaceholderEmpty(
        icon: Icons.rss_feed,
        title: '还没有订阅源',
        description: '添加一个 RSS / Atom 地址，比如 https://sspai.com/feed',
        action: FilledButton(
          onPressed: () => _showAddFeedDialog(context),
          child: const Text('添加订阅'),
        ),
      );
    }

    final List<Widget> items = <Widget>[];
    for (final String group in store.groups) {
      final List<Feed> feeds =
          store.feeds.where((Feed f) => f.group == group).toList();
      if (feeds.isEmpty) {
        continue;
      }
      items.add(_GroupHeader(name: group, count: feeds.length));
      for (final Feed feed in feeds) {
        final int unread = store.unreadCountOfFeed(feed.id);
        items.add(
          _FeedTile(
            feed: feed,
            unread: unread,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FeedArticlesPage(feed: feed),
              ),
            ),
            onChangeGroup: () => _showGroupDialog(context, store, feed),
            onDelete: () => store.removeFeed(feed),
          ),
        );
        items.add(const SizedBox(height: AppSpacing.md));
      }
      items.add(const SizedBox(height: AppSpacing.sm));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.navBottom,
      ),
      children: items,
    );
  }

  Future<void> _showAddFeedDialog(BuildContext context) async {
    final AppStore store = AppStore.instance;
    final TextEditingController urlController = TextEditingController();
    final TextEditingController groupController = TextEditingController();

    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('添加订阅'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: urlController,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'RSS / Atom 地址',
                  hintText: 'https://example.com/feed.xml',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: groupController,
                decoration: const InputDecoration(
                  labelText: '分组（可选）',
                  hintText: '留空即「${Feed.defaultGroup}」',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (submitted != true || urlController.text.trim().isEmpty) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await store.addFeed(urlController.text, group: groupController.text);
    // 失败原因弹出来，避免用户只看到页面顶部的小字提示。
    final String? error = store.lastError;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _showGroupDialog(
    BuildContext context,
    AppStore store,
    Feed feed,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: feed.group);
    final List<String> suggestions = store.groups
        .where((String g) => g != feed.group)
        .toList();

    final String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('「${feed.title}」的分组'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (suggestions.isNotEmpty) ...<Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  children: suggestions
                      .map(
                        (String name) => ActionChip(
                          label: Text(name),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(name),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '分组名称',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (String value) =>
                    Navigator.of(dialogContext).pop(value),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (selected != null) {
      store.setFeedGroup(feed, selected);
    }
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            name,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$count', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.feed,
    required this.unread,
    required this.onOpen,
    required this.onChangeGroup,
    required this.onDelete,
  });

  final Feed feed;
  final int unread;
  final VoidCallback onOpen;
  final VoidCallback onChangeGroup;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              color: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              border: Border.all(
                color:
                    (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                        .withValues(alpha: isDark ? 1 : 0.7),
              ),
              boxShadow: isDark ? AppShadows.cardDark : AppShadows.card,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.rss_feed,
                    size: 20,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        feed.title,
                        style:
                            theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feed.lastFetched == null
                            ? feed.url
                            : '${relativeTime(feed.lastFetched)}更新',
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  tooltip: '更多',
                  onSelected: (String value) {
                    if (value == 'group') {
                      onChangeGroup();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'group',
                      child: Text('修改分组'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('删除订阅'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
