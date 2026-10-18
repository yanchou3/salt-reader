import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/app_store.dart';
import 'features/shell/app_shell.dart';

/// 应用根：椒盐音乐风格的极简留白主题（浅/深双套，可跟随系统或手动指定）。
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
        home: const AppShell(),
      ),
    );
  }
}
