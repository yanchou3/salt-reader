import 'package:flutter/foundation.dart';

/// 正文字体可选方案。
///
/// 用系统自带字体，不打包字体文件：Windows 用宋体 / 楷体 / 微软雅黑，
/// Android 用系统 serif / sans-serif 族。楷体在 Android 上通常没有内置，
/// 会退回系统默认字体。
enum ReaderFont {
  system('系统默认'),
  serif('宋体'),
  kai('楷体'),
  sans('黑体');

  const ReaderFont(this.label);

  final String label;

  static ReaderFont fromName(String? name) {
    for (final ReaderFont font in values) {
      if (font.name == name) {
        return font;
      }
    }
    return ReaderFont.system;
  }

  /// 交给 Flutter 的字体族名；null 表示使用系统默认字体。
  String? get family {
    switch (this) {
      case ReaderFont.system:
        return null;
      case ReaderFont.serif:
        return _perPlatform(windows: 'SimSun', fallback: 'serif');
      case ReaderFont.kai:
        // Android 没有内置楷体，退回默认字体，避免显示成方框。
        return _perPlatform(windows: 'KaiTi', fallback: null);
      case ReaderFont.sans:
        return _perPlatform(
          windows: 'Microsoft YaHei',
          fallback: 'sans-serif',
        );
    }
  }

  static String? _perPlatform({
    required String windows,
    required String? fallback,
  }) {
    return defaultTargetPlatform == TargetPlatform.windows
        ? windows
        : fallback;
  }
}
