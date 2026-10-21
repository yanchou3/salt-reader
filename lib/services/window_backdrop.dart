import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Windows 窗口级背景（Mica）：让窗口真正透出桌面，而不只是应用内部的模糊。
///
/// 做法与 Flutter 里 `BackdropFilter` 完全不是一回事：
/// 由 DWM 在窗口底层绘制壁纸色调的材质，Flutter 只需要把背景留出透明度。
/// 这需要把整块客户区标记为「玻璃」（[DwmExtendFrameIntoClientArea]），
/// 否则透明像素会被当作黑色。
class WindowBackdrop {
  WindowBackdrop._();

  static bool _resolved = false;
  static bool _supported = false;
  static bool _enabled = false;
  static bool _desired = true;
  static int _hwnd = 0;
  static bool? _lastDark;
  static _SetAttributeDart? _setAttribute;
  static _ExtendFrameDart? _extendFrame;

  /// 系统背景当前是否真的生效。根部的极光底据此决定是否半透明。
  static bool get enabled => _enabled;

  /// 当前窗口是否支持切换（Windows 上找到了主窗口）。
  static bool get supported => _supported;

  // DWMWINDOWATTRIBUTE 的取值，见 dwmapi.h。
  static const int _dwmwaUseImmersiveDarkMode = 20;
  static const int _dwmwaSystemBackdropType = 38;

  /// DWMSBT_MAINWINDOW：随桌面壁纸着色的 Mica。
  static const int _backdropMica = 2;

  /// DWMSBT_NONE：关闭系统背景。
  static const int _backdropNone = 1;

  /// 与 windows/runner 里的窗口类名保持一致，用来拿到主窗口句柄。
  static const String _windowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

  /// 在 Windows 上给主窗口挂 Mica；其他平台或失败时静默跳过。
  ///
  /// 必须在窗口创建之后调用（`main()` 里即可），失败不会影响应用运行。
  static void apply({required bool dark, required bool enabled}) {
    if (!Platform.isWindows || _resolved) {
      return;
    }
    _resolved = true;
    try {
      final DynamicLibrary user32 = DynamicLibrary.open('user32.dll');
      final DynamicLibrary dwmapi = DynamicLibrary.open('dwmapi.dll');

      final _FindWindowDart findWindow = user32
          .lookupFunction<_FindWindowNative, _FindWindowDart>('FindWindowW');
      final _ExtendFrameDart extendFrame = dwmapi.lookupFunction<
          _ExtendFrameNative, _ExtendFrameDart>('DwmExtendFrameIntoClientArea');
      final _SetAttributeDart setAttribute = dwmapi.lookupFunction<
          _SetAttributeNative, _SetAttributeDart>('DwmSetWindowAttribute');

      final Pointer<Utf16> className = _windowClass.toNativeUtf16();
      final int hwnd = findWindow(className, nullptr);
      calloc.free(className);
      if (hwnd == 0) {
        return;
      }

      _hwnd = hwnd;
      _setAttribute = setAttribute;
      _extendFrame = extendFrame;
      _supported = true;
      _lastDark = dark;
      _setInt(
        setAttribute,
        hwnd,
        _dwmwaUseImmersiveDarkMode,
        dark ? 1 : 0,
      );
      _desired = enabled;
      _applyState();
    } catch (_) {
      _supported = false;
      _enabled = false;
    }
  }

  /// 运行时开关（设置页里的「系统 Mica 背景」）。
  static void setEnabled(bool enabled) {
    if (_desired == enabled || !_supported) {
      return;
    }
    _desired = enabled;
    _applyState();
  }

  /// 跟随应用主题切换 Mica 的深浅（同时影响标题栏配色）。
  static void setDark(bool dark) {
    final _SetAttributeDart? setAttribute = _setAttribute;
    if (!_supported || _hwnd == 0 || setAttribute == null || _lastDark == dark) {
      return;
    }
    _lastDark = dark;
    _setInt(setAttribute, _hwnd, _dwmwaUseImmersiveDarkMode, dark ? 1 : 0);
  }

  static void _applyState() {
    final _SetAttributeDart? setAttribute = _setAttribute;
    if (!_supported || _hwnd == 0 || setAttribute == null) {
      return;
    }
    if (_desired) {
      // 负边距 = 把整个客户区扩展进玻璃区域，透明像素才会露出背后的 Mica。
      _setMargins(-1, -1, -1, -1);
      // 只有 Windows 11 22H2+ 支持这个属性；旧系统会返回错误码，
      // 此时回退到不透明背景，看起来和以前一样。
      _enabled = _setInt(
            setAttribute,
            _hwnd,
            _dwmwaSystemBackdropType,
            _backdropMica,
          ) ==
          0;
      if (!_enabled) {
        _setMargins(0, 0, 1, 0);
      }
    } else {
      _setInt(setAttribute, _hwnd, _dwmwaSystemBackdropType, _backdropNone);
      // 恢复默认边距，避免窗口在关闭玻璃后留下透明边。
      _setMargins(0, 0, 1, 0);
      _enabled = false;
    }
  }

  static void _setMargins(int left, int top, int right, int bottom) {
    final _ExtendFrameDart? extendFrame = _extendFrame;
    if (extendFrame == null) {
      return;
    }
    final Pointer<_Margins> margins = calloc<_Margins>();
    margins.ref
      ..left = left
      ..top = top
      ..right = right
      ..bottom = bottom;
    extendFrame(_hwnd, margins);
    calloc.free(margins);
  }

  static int _setInt(
    _SetAttributeDart setAttribute,
    int hwnd,
    int attribute,
    int value,
  ) {
    final Pointer<Int32> buffer = calloc<Int32>();
    buffer.value = value;
    final int result =
        setAttribute(hwnd, attribute, buffer.cast(), sizeOf<Int32>());
    calloc.free(buffer);
    return result;
  }
}

final class _Margins extends Struct {
  @Int32()
  external int left;

  @Int32()
  external int top;

  @Int32()
  external int right;

  @Int32()
  external int bottom;
}

typedef _FindWindowNative = IntPtr Function(Pointer<Utf16>, Pointer<Utf16>);
typedef _FindWindowDart = int Function(Pointer<Utf16>, Pointer<Utf16>);

typedef _ExtendFrameNative = Int32 Function(IntPtr, Pointer<_Margins>);
typedef _ExtendFrameDart = int Function(int, Pointer<_Margins>);

typedef _SetAttributeNative = Int32 Function(
  IntPtr,
  Uint32,
  Pointer<Void>,
  Uint32,
);
typedef _SetAttributeDart = int Function(int, int, Pointer<Void>, int);
