import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// 当前安装包的版本信息（启动时由 [load] 读取，之后各处直接读静态字段）。
class AppInfo {
  AppInfo._();

  /// 应用显示名，如「椒盐阅读」。
  static String name = '椒盐阅读';

  /// 版本号，如 0.1.6。
  static String version = '0.0.0';

  /// 构建号，如 7。
  static String buildNumber = '0';

  /// 形如 0.1.6 (7)。
  static String get versionLabel => '$version ($buildNumber)';

  /// 形如 Windows · 0.1.6 (7)。
  static String get platformLabel {
    if (Platform.isWindows) {
      return 'Windows';
    }
    if (Platform.isAndroid) {
      return 'Android';
    }
    if (Platform.isMacOS) {
      return 'macOS';
    }
    if (Platform.isLinux) {
      return 'Linux';
    }
    return '本机';
  }

  /// 读取真实安装版本；失败时保留默认值，不影响启动。
  static Future<void> load() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (info.appName.trim().isNotEmpty) {
        name = info.appName.trim();
      }
      version = info.version.isEmpty ? version : info.version;
      buildNumber = info.buildNumber.isEmpty ? buildNumber : info.buildNumber;
    } catch (_) {
      // 忽略：读不到版本时页面显示默认值即可。
    }
  }
}
