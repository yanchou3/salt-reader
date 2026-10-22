import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/glass.dart';
import 'data/app_store.dart';
import 'features/shell/app_shell.dart';
import 'services/window_backdrop.dart';

/// 应用根：椒盐音乐风格的极简留白主题（浅/深双套，可跟随系统或手动指定）。
///
/// 整个窗口铺一层极光底（[AuroraBackground]），页面用透明 Scaffold 透出它；
/// 这样各处玻璃组件背后才有内容可模糊，「液态玻璃」才成立。
///
/// 只监听「主题模式」这一个字段：AppStore 在刷新、预抓全文时会频繁通知，
/// 若整棵树跟着重建，滚动就会周期性卡顿。
class RssReaderApp extends StatefulWidget {
  const RssReaderApp({super.key});

  @override
  State<RssReaderApp> createState() => _RssReaderAppState();
}

class _RssReaderAppState extends State<RssReaderApp> {
  late ThemeMode _themeMode = AppStore.instance.themeMode;

  /// 窗口 Mica 是否生效：决定极光底要不要留出透明度。
  bool _translucent = WindowBackdrop.enabled;

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    final ThemeMode mode = AppStore.instance.themeMode;
    final bool translucent = WindowBackdrop.enabled;
    if (mode != _themeMode || translucent != _translucent) {
      setState(() {
        _themeMode = mode;
        _translucent = translucent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '椒盐阅读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      builder: (BuildContext context, Widget? navigator) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 极光底是静态的，单独缓存一层，页面切换时不必重新绘制。
          RepaintBoundary(child: AuroraBackground(translucent: _translucent)),
          ?navigator,
        ],
      ),
      home: const AppShell(),
    );
  }
}
