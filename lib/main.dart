import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_info.dart';
import 'data/app_store.dart';
import 'services/window_backdrop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.load();
  try {
    await AppStore.instance.load();
  } catch (error, stack) {
    // 本地数据读取失败不应阻塞启动，否则会停在启动图（黑屏）。
    debugPrint('启动加载失败：$error\n$stack');
  }
  // Windows 上给窗口挂系统 Mica：窗口能透出桌面壁纸的色调。
  // 旧系统或调用失败时静默回退到应用内不透明背景。
  WindowBackdrop.apply(dark: _resolvedDark());
  // 用户切浅色 / 深色时，Mica 与标题栏跟着变。
  AppStore.instance.addListener(_syncWindowMaterial);
  runApp(const RssReaderApp());
  // 恢复上次选中的字体（内置字体可能需要联网下载，放到首帧之后）。
  unawaited(AppStore.instance.ensureReaderFontReady());
  // 静默检查更新：延后几秒，避开启动时的订阅刷新。
  if (AppStore.instance.autoCheckUpdate) {
    unawaited(
      Future<void>.delayed(const Duration(seconds: 5)).then(
        (void _) => AppStore.instance.checkForUpdate(silent: true),
      ),
    );
  }
}

/// 当前主题实际是深色还是浅色（跟随系统时取系统亮度）。
bool _resolvedDark() {
  final ThemeMode mode = AppStore.instance.themeMode;
  return mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
}

/// AppStore 每次通知都会调用，交给 [WindowBackdrop.setDark] 自己去重。
void _syncWindowMaterial() {
  WindowBackdrop.setDark(_resolvedDark());
}
