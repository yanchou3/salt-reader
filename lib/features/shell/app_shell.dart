import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../articles/article_list_page.dart';
import '../feeds/feeds_page.dart';
import '../settings/settings_page.dart';
import '../starred/starred_page.dart';

/// 应用外壳：底部导航（椒盐式的悬浮毛玻璃圆角导航条）。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    ArticleListPage(),
    FeedsPage(),
    StarredPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color outline = isDark
        ? AppColors.darkOutline
        : AppColors.lightOutline;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: outline.withValues(alpha: 0.7),
                  ),
                  boxShadow: isDark ? AppShadows.softDark : AppShadows.soft,
                ),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _index,
                  onDestinationSelected: (int i) => setState(() => _index = i),
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.inbox_outlined),
                      selectedIcon: Icon(Icons.inbox_rounded),
                      label: '未读',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.rss_feed),
                      label: '订阅',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bookmark_outline),
                      selectedIcon: Icon(Icons.bookmark),
                      label: '收藏',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: '设置',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
