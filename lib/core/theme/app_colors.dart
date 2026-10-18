import 'package:flutter/material.dart';

/// 椒盐音乐风格的中性色板 + 单一强调色。
/// 大面积中性灰白，仅用一个强调色点亮，是这套视觉语言的核心。
class AppColors {
  AppColors._();

  /// 强调色（后续可做成可配置 / 跟随封面取色）。
  static const Color accent = Color(0xFFE8554F);
  static const Color accentSoft = Color(0xFFFDECEB);

  // ---- 浅色 ----
  static const Color lightBg = Color(0xFFFAFAFB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF2F2F4);
  static const Color lightText = Color(0xFF16161A);
  static const Color lightTextSecondary = Color(0xFF8A8A90);
  static const Color lightOutline = Color(0xFFEDEDF0);

  // ---- 深色 ----
  static const Color darkBg = Color(0xFF0E0E10);
  static const Color darkSurface = Color(0xFF17171A);
  static const Color darkSurfaceAlt = Color(0xFF1F1F24);
  static const Color darkText = Color(0xFFF2F2F5);
  static const Color darkTextSecondary = Color(0xFF9A9AA2);
  static const Color darkOutline = Color(0xFF2A2A30);
}
