import 'package:flutter/material.dart';

/// 统一间距体系，避免各页面随手写数字导致节奏漂移。
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// 列表底部的「导航条留白」：正文延伸到玻璃导航条下方后，
  /// 需要留出足够空间，最后一张卡片才不会被浮动导航条压住。
  static const double navBottom = 120;
}

/// 大圆角是本套风格的重要特征。
class AppRadius {
  AppRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// 克制的柔阴影（椒盐式低海拔、大扩散）。
class AppShadows {
  AppShadows._();

  /// 列表卡片用的单层轻阴影：层数少、blur 小，降低滚动时的 overdraw。
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> cardDark = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 28,
      offset: Offset(0, 10),
      spreadRadius: -8,
    ),
    BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> softDark = <BoxShadow>[
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 28,
      offset: Offset(0, 10),
      spreadRadius: -8,
    ),
  ];
}
