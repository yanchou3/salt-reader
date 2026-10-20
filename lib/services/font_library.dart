import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme/reader_fonts.dart';

/// 字体下载 / 注册失败时抛出的异常，[message] 可直接展示给用户。
class FontLibraryException implements Exception {
  const FontLibraryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 管字体的「文件」与「注册」两件事。
///
/// 内置字体（思源宋体 / 霞鹜文楷）首次选中时联网下载并缓存到应用目录；
/// 下载按 [ReaderFont.sources] 顺序逐个尝试（国内镜像优先），
/// 并对拿到的字节做字体格式校验，避免把错误页或残缺文件注册成字体。
/// 用户本地导入的 ttf/otf 会拷贝进应用目录，避免原文件被移动/删除后失效。
class FontLibrary {
  FontLibrary._();

  static final FontLibrary instance = FontLibrary._();

  /// 单个源的连接超时；连不上就尽快换下一个源。
  static const Duration _connectTimeout = Duration(seconds: 12);

  /// 单个源的接收超时（按单次数据间隔计），大文件需要留足。
  static const Duration _receiveTimeout = Duration(minutes: 3);

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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
  ///
  /// 若本地已有文件但格式不对（下载中断、被错误页覆盖等），会删掉重新下载。
  Future<bool> ensure(
    ReaderFont font, {
    void Function(int received, int total, String source)? onProgress,
  }) async {
    if (font.isSystem) {
      return true;
    }
    if (_registered.contains(font.id)) {
      return true;
    }
    final File file = await _fileFor(font);
    if (await file.exists()) {
      if (await _looksLikeFontFile(file)) {
        return _register(font, file);
      }
      await file.delete();
    }
    if (font.sources.isEmpty) {
      throw FontLibraryException('「${font.label}」没有可用的下载地址');
    }
    await _download(font, file, onProgress);
    return _register(font, file);
  }

  /// 逐个源尝试下载，全部失败时抛出带原因的 [FontLibraryException]。
  Future<void> _download(
    ReaderFont font,
    File target,
    void Function(int received, int total, String source)? onProgress,
  ) async {
    final File tmp = File('${target.path}.part');
    final List<String> failures = <String>[];
    for (final String url in font.sources) {
      final String source = sourceLabel(url);
      try {
        await _dio.download(
          url,
          tmp.path,
          onReceiveProgress: (int received, int total) =>
              onProgress?.call(received, total, source),
          options: Options(
            followRedirects: true,
            connectTimeout: _connectTimeout,
            receiveTimeout: _receiveTimeout,
            sendTimeout: _connectTimeout,
            headers: const <String, String>{'User-Agent': _userAgent},
          ),
        );
        if (!await _looksLikeFontFile(tmp)) {
          throw const FontLibraryException('拿到的不是字体文件');
        }
        if (await target.exists()) {
          await target.delete();
        }
        await tmp.rename(target.path);
        return;
      } catch (error) {
        failures.add('$source（${_shortReason(error)}）');
      } finally {
        if (await tmp.exists()) {
          await tmp.delete();
        }
      }
    }
    throw FontLibraryException(
      '「${font.label}」下载失败，已尝试 ${failures.length} 个源：${failures.join('、')}',
    );
  }

  /// 镜像的中文名字，用于界面上显示「正在从哪儿下」。
  static String sourceLabel(String url) {
    final String host = Uri.tryParse(url)?.host ?? '';
    if (host.endsWith('huaweicloud.com')) {
      return '华为云镜像';
    }
    if (host.endsWith('sjtug.sjtu.edu.cn')) {
      return '上海交大镜像';
    }
    if (host.endsWith('nju.edu.cn')) {
      return '南京大学镜像';
    }
    if (host.endsWith('hit.edu.cn')) {
      return '哈工大镜像';
    }
    if (host.endsWith('sdu.edu.cn')) {
      return '山东大学镜像';
    }
    if (host.endsWith('gh-proxy.com') || host.endsWith('ghproxy.net')) {
      return 'GitHub 代理';
    }
    return host.isEmpty ? '未知来源' : host;
  }

  /// 只读文件头就能判断是不是 FontLoader 能吃下的字体。
  static Future<bool> _looksLikeFontFile(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final Uint8List head = await raf.read(4);
      if (head.length < 4) {
        return false;
      }
      // 0x00010000：TrueType；OTTO：CFF/OpenType；true/typ1：旧版 TrueType；
      // ttcf：字体集合。woff/woff2 浏览器才认，Flutter 不支持，直接判失败。
      const int trueType = 0x00010000;
      final int tag = (head[0] << 24) | (head[1] << 16) | (head[2] << 8) | head[3];
      final String ascii = String.fromCharCodes(head);
      return tag == trueType ||
          ascii == 'OTTO' ||
          ascii == 'true' ||
          ascii == 'typ1' ||
          ascii == 'ttcf';
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }

  /// 把一次失败压缩成一句短话，拼进最终错误提示里。
  static String _shortReason(Object error) {
    if (error is FontLibraryException) {
      return error.message;
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.badResponse:
          final int? code = error.response?.statusCode;
          return code == null ? '服务端返回异常' : 'HTTP $code';
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return '连接超时';
        case DioExceptionType.connectionError:
          return '连不上';
        case DioExceptionType.badCertificate:
          return '证书校验失败';
        case DioExceptionType.cancel:
          return '已取消';
        case DioExceptionType.unknown:
          final Object? cause = error.error;
          return cause is SocketException
              ? (cause.osError?.message ?? '网络错误')
              : '网络错误';
      }
    }
    return '未知错误';
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
