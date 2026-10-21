import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 把桌面端鼠标滚轮从「一格一跳」变成连续滚动。
///
/// Flutter 默认处理滚轮时直接 `forcePixels` 到目标位置：每转一格内容瞬移
/// 一大段，两次事件之间屏幕完全静止，视觉上就是一顿一顿的。这里改写
/// [ScrollPosition.pointerScroll]，把位移累积成一个目标值，再用 Ticker
/// 每帧逼近目标，得到平滑滚动。
///
/// 只接管滚轮；手指/鼠标拖拽、惯性滚动、滚动条拖动都不受影响——
/// 一旦检测到滚动位置被其他来源改动就立刻让出控制权。
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class SmoothScrollPosition extends ScrollPositionWithSingleContext {
  SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  Ticker? _ticker;

  /// 滚轮累积的目标位置（null 表示没有待处理的滚动）。
  double? _target;

  /// 上一帧由本类写入的位置，用来识别外部滚动（拖拽等）。
  double _lastApplied = double.nan;

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      // 取消惯性 / 滚轮滚动。
      _stop();
      goBallistic(0.0);
      return;
    }
    final double from = _target ?? pixels;
    final double target = (from + delta).clamp(
      minScrollExtent,
      maxScrollExtent,
    );
    if ((target - pixels).abs() < 0.5) {
      return;
    }
    _target = target;
    goIdle();
    updateUserScrollDirection(
      delta < 0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    isScrollingNotifier.value = true;
    final Ticker ticker = _ticker ??= context.vsync.createTicker(_onTick);
    if (!ticker.isActive) {
      _lastApplied = pixels;
      ticker.start();
    }
  }

  void _onTick(Duration _) {
    final double? target = _target;
    if (target == null || !hasPixels) {
      _stop();
      return;
    }
    // 用户开始拖拽 / 拖动滚动条：停手，不与用户抢。
    if (pixels != _lastApplied) {
      _stop();
      return;
    }
    final double clamped = target.clamp(minScrollExtent, maxScrollExtent);
    final double remaining = clamped - pixels;
    if (remaining.abs() < 0.5) {
      final double oldPixels = pixels;
      forcePixels(clamped);
      didUpdateScrollPositionBy(pixels - oldPixels);
      _lastApplied = clamped;
      _stop();
      goBallistic(0.0);
      return;
    }
    // 指数逼近：起步快、收尾稳，连续滚轮也不会出现速度突变。
    final double oldPixels = pixels;
    forcePixels(pixels + remaining * 0.3);
    didUpdateScrollPositionBy(pixels - oldPixels);
    _lastApplied = pixels;
  }

  void _stop() {
    final Ticker? ticker = _ticker;
    if (ticker != null && ticker.isActive) {
      ticker.stop();
    }
    _target = null;
    isScrollingNotifier.value = false;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

/// 列表页用：自己持有一个 [SmoothScrollController]，通过 [builder] 交给滚动视图。
class SmoothWheelArea extends StatefulWidget {
  const SmoothWheelArea({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<SmoothWheelArea> createState() => _SmoothWheelAreaState();
}

class _SmoothWheelAreaState extends State<SmoothWheelArea> {
  final SmoothScrollController _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _scroll);
}
