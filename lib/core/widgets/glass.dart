import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 液态玻璃（liquid glass）设计令牌：透明度、模糊半径、高光与描边。
///
/// 全部集中在这里，避免各页面随手写 alpha / sigma 导致风格漂移。
class GlassTokens {
  GlassTokens._();

  /// chrome 层（导航条、AppBar）的模糊半径。
  static const double blurChrome = 24;

  /// 浮层（对话框、底部面板）的模糊半径：更厚，需要更强的模糊。
  static const double blurSheet = 34;

  /// 面板 / 分组的模糊半径。
  static const double blurPanel = 18;

  /// 玻璃底色：浅色偏白、深色偏黑。alpha 决定「透」的程度。
  static Color tint(Brightness brightness, double alpha) {
    final Color base = brightness == Brightness.dark
        ? const Color(0xFF141419)
        : Colors.white;
    return base.withValues(alpha: alpha);
  }

  /// 斜向迎光面高光叠加在底色之上，让玻璃有「被照亮」的层次。
  static Color sheen(Brightness brightness) => Colors.white.withValues(
        alpha: brightness == Brightness.dark ? 0.06 : 0.34,
      );

  /// 玻璃外描边，勾出边界而不抢内容。
  static Color border(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);

  /// 玻璃投射的柔影。
  static List<BoxShadow> shadow(Brightness brightness) =>
      brightness == Brightness.dark ? AppShadows.softDark : AppShadows.soft;

  /// chrome 层底色（导航条 / AppBar）。
  static const double alphaChrome = 0.62;

  /// 浮层底色（对话框 / 底部面板）：更实一点，保证浮层上的字清楚。
  static const double alphaSheet = 0.74;

  /// 面板底色。
  static const double alphaPanel = 0.66;

  /// 卡片底色：不采样背景，需要一点实体感。
  static const double alphaCard = 0.68;
}

/// 液态玻璃容器：半透明底 + 背景模糊 + 迎光高光 + 细描边 + 柔影。
///
/// [blur] 为 false 时只保留半透明「玻璃质感」而**不采样背景**——
/// 列表项这类大量重复的组件必须这么用：滚动时每一帧重算模糊会明显掉帧。
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.borderRadius,
    this.blurSigma,
    this.tintAlpha,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blur = true,
    this.sheen = true,
    this.showBorder = true,
    this.showShadow = true,
    this.gradient,
  });

  final Widget? child;
  final BorderRadius? borderRadius;
  final double? blurSigma;
  final double? tintAlpha;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool blur;
  final bool sheen;
  final bool showBorder;
  final bool showShadow;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final double alpha = tintAlpha ?? GlassTokens.alphaPanel;
    final Color tint = GlassTokens.tint(brightness, alpha);

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                tint,
                GlassTokens.tint(brightness, (alpha * 0.84).clamp(0.0, 1.0)),
              ],
            ),
        border: showBorder
            ? Border.all(color: GlassTokens.border(brightness))
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              if (sheen) GlassTokens.sheen(brightness),
              Colors.transparent,
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.38, 1.0],
          ),
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    body = ClipRRect(borderRadius: radius, child: body);
    if (blur) {
      body = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma ?? GlassTokens.blurPanel,
            sigmaY: blurSigma ?? GlassTokens.blurPanel,
          ),
          child: body,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: showShadow ? GlassTokens.shadow(brightness) : null,
      ),
      child: body,
    );
  }
}

/// 液态玻璃的「底」——一层柔和的极光渐变。
///
/// 没有它，[BackdropFilter] 只能模糊一片纯色，玻璃感就会消失：
/// 玻璃必须「有东西可透」。
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.lightBg,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _AuroraBlob(
              alignment: const Alignment(-1.45, -1.25),
              size: 640,
              color: AppColors.accent,
              alpha: isDark ? 0.34 : 0.22,
            ),
            _AuroraBlob(
              alignment: const Alignment(1.6, -0.45),
              size: 520,
              color: const Color(0xFF7C8CFF),
              alpha: isDark ? 0.24 : 0.16,
            ),
            _AuroraBlob(
              alignment: const Alignment(-0.5, 1.6),
              size: 580,
              color: const Color(0xFF4FC3B1),
              alpha: isDark ? 0.18 : 0.13,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({
    required this.alignment,
    required this.size,
    required this.color,
    required this.alpha,
  });

  final Alignment alignment;
  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// 玻璃 AppBar：透明底 + 背后实时模糊 + 下沿一条细高光。
///
/// 页面内容滚到它下方时会被实时模糊，是「液态玻璃」最直观的一处。
/// 用法与 [AppBar] 一致，直接替换即可。
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.bottom,
    this.height = kToolbarHeight,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final double height;

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: height,
      title: title,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      bottom: bottom,
      flexibleSpace: Container(
        // 下沿细线用前景绘制，才不会被玻璃底盖住。
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: GlassTokens.border(brightness)),
          ),
        ),
        child: const GlassContainer(
          borderRadius: BorderRadius.zero,
          blurSigma: GlassTokens.blurChrome,
          tintAlpha: GlassTokens.alphaChrome,
          showBorder: false,
          showShadow: false,
        ),
      ),
    );
  }
}

/// 玻璃对话框主体：标题 / 正文 / 操作按钮三段式浮层骨架。
///
/// 直接替代 `AlertDialog`：它没有自己的实心底，玻璃的透明度与实时模糊
/// 才能真正透出背后的内容。需要通过 [showGlassDialog] 打开。
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.maxContentWidth = 380,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  /// 正文最大宽度（不含内边距）：桌面端避免一行字数过多。
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GlassContainer(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      blurSigma: GlassTokens.blurSheet,
      tintAlpha: GlassTokens.alphaSheet,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Material(
          // 透明 Material 只提供按钮水波纹 / ListTile 的绘制层，不产生底色。
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (title != null)
                DefaultTextStyle.merge(
                  style: theme.textTheme.titleLarge ?? const TextStyle(),
                  child: title!,
                ),
              if (title != null) const SizedBox(height: AppSpacing.lg),
              if (content != null) Flexible(child: content!),
              if (actions != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    for (int i = 0; i < actions!.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      actions![i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 玻璃对话框：替代 [showDialog] 的默认实心底，换成实时模糊的玻璃浮层。
///
/// 用 [showGeneralDialog] 自己接管转场，才能把 [GlassDialog] 放进页面层
/// 而不是被 `Dialog` 的主题底色挡住。
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.26),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (BuildContext context, Animation<double> a, Animation<double> b) {
      final MediaQueryData media = MediaQuery.of(context);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            // 键盘弹出时把浮层整体抬起，输入框不会被遮住。
            AppSpacing.lg + media.viewInsets.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: media.size.height * 0.82,
              ),
              child: builder(context),
            ),
          ),
        ),
      );
    },
    transitionBuilder:
        (BuildContext context, Animation<double> a, Animation<double> b, Widget? child) {
      final Animation<double> curved =
          CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 玻璃底部面板：替代 [showModalBottomSheet] 的实心面板。
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    showDragHandle: true,
    builder: (BuildContext sheetContext) => GlassContainer(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      blurSigma: GlassTokens.blurSheet,
      tintAlpha: GlassTokens.alphaSheet,
      showShadow: false,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).padding.bottom,
      ),
      child: builder(sheetContext),
    ),
  );
}
