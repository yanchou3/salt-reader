import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';
import '../widgets/glass.dart';

/// 椒盐音乐风格主题：中性底色 + 单一强调色 + 大圆角 + 克制海拔，
/// 表面统一走「液态玻璃」（半透明 + 模糊 + 高光描边）。
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: AppColors.lightBg,
        surface: AppColors.lightSurface,
        surfaceAlt: AppColors.lightSurfaceAlt,
        text: AppColors.lightText,
        textSecondary: AppColors.lightTextSecondary,
        outline: AppColors.lightOutline,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBg,
        surface: AppColors.darkSurface,
        surfaceAlt: AppColors.darkSurfaceAlt,
        text: AppColors.darkText,
        textSecondary: AppColors.darkTextSecondary,
        outline: AppColors.darkOutline,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color text,
    required Color textSecondary,
    required Color outline,
  }) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceAlt,
      outline: outline,
      outlineVariant: outline,
    );

    final TextTheme textTheme = AppTypography.textTheme(text, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // 页面背景交给根部的 AuroraBackground，各页 Scaffold 保持透明。
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        // AppBar 的玻璃由各页的 flexibleSpace（GlassContainer）提供，
        // 这里只保证默认底色是透的。
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: text, size: 22),
      ),
      dialogTheme: DialogThemeData(
        // 应用内的对话框都走 showGlassDialog（自带实时模糊）；
        // 这里只是第三方内置对话框的兜底：较厚的半透明底，字仍清楚。
        backgroundColor: GlassTokens.tint(brightness, 0.88),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: GlassTokens.border(brightness)),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: GlassTokens.tint(brightness, 0.90),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: GlassTokens.tint(brightness, 0.90),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 22),
      navigationBarTheme: NavigationBarThemeData(
        // 导航条自身的玻璃由 AppShell 提供，这里保持透明。
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.accent : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.accent : textSecondary,
          );
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        // 胶囊筛选条做成玻璃质感。
        backgroundColor: GlassTokens.tint(brightness, 0.52),
        selectedColor: AppColors.accent.withValues(alpha: 0.16),
        side: BorderSide(color: GlassTokens.border(brightness)),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            return states.contains(WidgetState.selected)
                ? AppColors.accent.withValues(alpha: 0.12)
                : Colors.transparent;
          }),
          foregroundColor:
              WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            return states.contains(WidgetState.selected)
                ? AppColors.accent
                : textSecondary;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
    );
  }
}
