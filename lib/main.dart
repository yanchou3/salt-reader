import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppStore.instance.load();
  } catch (error, stack) {
    // 本地数据读取失败不应阻塞启动，否则会停在启动图（黑屏）。
    debugPrint('启动加载失败：$error\n$stack');
  }
  runApp(const RssReaderApp());
}
