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
class RssReaderApp extends StatelessWidget {
  const RssReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (BuildContext context, Widget? child) => MaterialApp(
        title: '椒盐阅读',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: AppStore.instance.themeMode,
        builder: (BuildContext context, Widget? navigator) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AuroraBackground(translucent: WindowBackdrop.applied),
            ?navigator,
          ],
        ),
        home: const AppShell(),
      ),
    );
  }
}
