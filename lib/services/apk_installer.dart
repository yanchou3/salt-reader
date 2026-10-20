import 'dart:io';

import 'package:flutter/services.dart';

/// 调起系统安装器安装下载好的 APK（仅 Android 生效）。
class ApkInstaller {
  ApkInstaller._();

  static const MethodChannel _channel = MethodChannel('salt_reader/install');

  /// 是否已允许本应用「安装未知来源应用」。
  static Future<bool> canInstall() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 跳转到系统的「安装未知应用」授权页。
  static Future<void> openInstallSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // 部分定制系统没有该页面，忽略即可。
    } on MissingPluginException {
      // 忽略。
    }
  }

  /// 调起安装器。
  static Future<void> install(File apk) async {
    if (!Platform.isAndroid) {
      throw const ApkInstallException('当前平台不支持直接安装');
    }
    try {
      await _channel.invokeMethod<void>('install', <String, String>{
        'path': apk.path,
      });
    } on PlatformException catch (error) {
      throw ApkInstallException(error.message ?? '调起安装器失败');
    } on MissingPluginException {
      throw const ApkInstallException('当前版本不支持应用内安装，请前往发布页手动下载');
    }
  }
}

class ApkInstallException implements Exception {
  const ApkInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}
