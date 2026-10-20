import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_info.dart';
import 'data/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.load();
  try {
    await AppStore.instance.load();
  } catch (error, stack) {
    // 本地数据读取失败不应阻塞启动，否则会停在启动图（黑屏）。
    debugPrint('启动加载失败：$error\n$stack');
  }
  runApp(const RssReaderApp());
  // 恢复上次选中的字体（内置字体可能需要联网下载，放到首帧之后）。
  unawaited(AppStore.instance.ensureReaderFontReady());
}
