import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/widgets/glass.dart';
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
    return Scaffold(
      // Scaffold 透明，透出根部 AuroraBackground，玻璃导航条才有东西可模糊。
      backgroundColor: Colors.transparent,
      // 导航条放在 Stack 里浮在正文之上（而不是 bottomNavigationBar），
      // 这样正文能滚到它后面透出来，点击命中区域也始终明确。
      body: Stack(
        children: <Widget>[
          // 把页面层和导航条分开：导航条切换动画每帧重绘时，
          // 整页内容不用跟着重新栅格化。
          RepaintBoundary(
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                for (int i = 0; i < _pages.length; i++)
                  TickerMode(enabled: i == _index, child: _pages[i]),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: RepaintBoundary(
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    // 导航条下沿每帧都有列表滚动，实时模糊会拖垮帧率；
                    // 用略更实的半透明底 + 迎光高光保留玻璃观感。
                    blur: false,
                    tintAlpha: GlassTokens.alphaChrome,
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      animationDuration: Duration.zero,
                      selectedIndex: _index,
                      onDestinationSelected: (int i) =>
                          setState(() => _index = i),
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
        ],
      ),
    );
  }
}
