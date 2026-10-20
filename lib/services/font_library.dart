import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme/reader_fonts.dart';

/// 管字体的「文件」与「注册」两件事。
///
/// 内置字体（思源宋体 / 霞鹜文楷）首次选中时联网下载并缓存到应用目录；
/// 用户本地导入的 ttf/otf 会拷贝进应用目录，避免原文件被移动/删除后失效。
class FontLibrary {
  FontLibrary._();

  static final FontLibrary instance = FontLibrary._();

  final Dio _dio = Dio();
  final Set<String> _registered = <String>{};

  Future<Directory> _fontsDir() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(
      '${base.path}${Platform.pathSeparator}fonts',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileFor(ReaderFont font) async {
    final Directory dir = await _fontsDir();
    return File('${dir.path}${Platform.pathSeparator}${font.id}.font');
  }

  /// 字体是否已经注册到渲染层（可直接使用）。
  bool isRegistered(ReaderFont font) =>
      font.isSystem || _registered.contains(font.id);

  /// 字体文件是否已在本地（无需联网即可注册）。
  Future<bool> isDownloaded(ReaderFont font) async {
    if (font.isSystem) {
      return true;
    }
    final File file = await _fileFor(font);
    return file.exists();
  }

  /// 确保字体可用：必要时下载，然后注册。成功返回 true。
  Future<bool> ensure(
    ReaderFont font, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (font.isSystem) {
      return true;
    }
    if (_registered.contains(font.id)) {
      return true;
    }
    final File file = await _fileFor(font);
    if (!await file.exists()) {
      final String? url = font.url;
      if (url == null || url.isEmpty) {
        return false;
      }
      await _download(url, file, onProgress);
    }
    return _register(font, file);
  }

  Future<void> _download(
    String url,
    File target,
    void Function(int received, int total)? onProgress,
  ) async {
    final File tmp = File('${target.path}.part');
    try {
      await _dio.download(
        url,
        tmp.path,
        onReceiveProgress: onProgress,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(seconds: 30),
          headers: const <String, String>{
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );
      if (await target.exists()) {
        await target.delete();
      }
      await tmp.rename(target.path);
    } finally {
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
  }

  Future<bool> _register(ReaderFont font, File file) async {
    final String? family = font.family;
    if (family == null) {
      return true;
    }
    try {
      final Uint8List bytes = await file.readAsBytes();
      final FontLoader loader = FontLoader(family);
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      _registered.add(font.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 把用户选中的本地字体写入应用目录，返回对应的字体对象。
  ///
  /// 用字节而不是路径：Android 上拿到的常是 content URI，没有可直接读取的路径。
  Future<ReaderFont> importBytes(Uint8List bytes, String label) async {
    final Directory dir = await _fontsDir();
    final String id = 'custom${DateTime.now().millisecondsSinceEpoch}';
    final File dest = File('${dir.path}${Platform.pathSeparator}$id.font');
    await dest.writeAsBytes(bytes, flush: true);
    return ReaderFont(id: id, label: label, isCustom: true);
  }

  /// 删除本地字体文件并注销。
  Future<void> remove(ReaderFont font) async {
    _registered.remove(font.id);
    final File file = await _fileFor(font);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
