import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// 远端最新版本信息。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tag,
    required this.notes,
    required this.publishedAt,
    required this.pageUrl,
    required this.apkUrl,
    required this.zipUrl,
  });

  /// 纯版本号，如 0.1.6。
  final String version;

  /// 发布 tag，如 v0.1.6。
  final String tag;

  /// 更新说明（Markdown 原文）。
  final String notes;

  final DateTime? publishedAt;

  /// 对应的发布页。
  final String pageUrl;

  /// Android 安装包直链（无则为 null）。
  final String? apkUrl;

  /// Windows 压缩包直链（无则为 null）。
  final String? zipUrl;
}

/// 检查更新 / 下载安装包过程中的可读错误。
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 检查更新与下载新版本。
///
/// 数据源为 GitHub Releases；国内网络下 `api.github.com` 偶发不可达，
/// 因此接口与资源都准备了「直连 → gh-proxy 代理」两档回退。
class Updater {
  Updater._();

  static final Updater instance = Updater._();

  static const String repoSlug = 'yanchou3/salt-reader';
  static const String repoUrl = 'https://github.com/$repoSlug';

  /// 发布页（打不开内置更新时可手动前往）。
  static const String releasesPageUrl = '$repoUrl/releases';

  /// 形如 https://github.com/yanchou3/salt-reader/releases/tag/v0.1.6
  static String tagUrl(String tag) => '$repoUrl/releases/tag/$tag';

  static final Dio _api = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: <String, String>{'Accept': 'application/vnd.github+json'},
    ),
  );

  static final Dio _downloader = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  /// 接口地址，直连优先，失败再走国内代理。
  List<String> get _apiSources => <String>[
    'https://api.github.com/repos/$repoSlug/releases?per_page=10',
    'https://gh-proxy.com/https://api.github.com/repos/$repoSlug/releases?per_page=10',
  ];

  /// 检查是否有比 [currentVersion] 更新的版本。
  ///
  /// 返回 null 表示已是最新（或远端没有可用版本）。
  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    final List<String> failures = <String>[];
    for (final String url in _apiSources) {
      try {
        final Response<dynamic> response = await _api.get<dynamic>(url);
        final UpdateInfo? info = _parse(response.data);
        if (info != null &&
            _compareVersions(info.version, currentVersion) > 0) {
          return info;
        }
        return null;
      } on DioException catch (error) {
        failures.add(_shortReason(error));
      } catch (error) {
        failures.add('$error');
      }
    }
    throw UpdateException('无法连接更新服务器（${failures.join('、')}），请检查网络');
  }

  /// 从 release 列表里取最新一条正式版。
  UpdateInfo? _parse(dynamic data) {
    if (data is! List<dynamic>) {
      return null;
    }
    for (final dynamic item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      if (item['draft'] == true || item['prerelease'] == true) {
        continue;
      }
      final String tag = (item['tag_name'] as String?)?.trim() ?? '';
      if (tag.isEmpty) {
        continue;
      }
      final String version = tag.replaceFirst(RegExp(r'^[vV]'), '');
      String? apk;
      String? zip;
      final dynamic assets = item['assets'];
      if (assets is List<dynamic>) {
        for (final dynamic asset in assets) {
          if (asset is! Map<String, dynamic>) {
            continue;
          }
          final String name = (asset['name'] as String?) ?? '';
          final String url = (asset['browser_download_url'] as String?) ?? '';
          if (url.isEmpty) {
            continue;
          }
          if (name.endsWith('.apk') && apk == null) {
            apk = url;
          } else if (name.endsWith('.zip') && zip == null) {
            zip = url;
          }
        }
      }
      return UpdateInfo(
        version: version,
        tag: tag,
        notes: (item['body'] as String?)?.trim() ?? '',
        publishedAt: DateTime.tryParse((item['published_at'] as String?) ?? '')
            ?.toLocal(),
        pageUrl: (item['html_url'] as String?) ?? tagUrl(tag),
        apkUrl: apk,
        zipUrl: zip,
      );
    }
    return null;
  }

  /// 下载 Android 安装包到缓存目录。
  Future<File> downloadApk(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final String? url = info.apkUrl;
    if (url == null) {
      throw const UpdateException('该版本没有提供 Android 安装包');
    }
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/salt-reader-${info.version}.apk');
    await _download(url, file, onProgress: onProgress);
    return file;
  }

  /// 下载 Windows 压缩包到「下载」目录，返回文件。
  Future<File> downloadWindowsZip(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final String? url = info.zipUrl;
    if (url == null) {
      throw const UpdateException('该版本没有提供 Windows 安装包');
    }
    final Directory dir =
        await getDownloadsDirectory() ?? await getApplicationSupportDirectory();
    final File file = File('${dir.path}/salt-reader-${info.version}-win64.zip');
    await _download(url, file, onProgress: onProgress);
    return file;
  }

  Future<void> _download(
    String url,
    File target, {
    void Function(int received, int total)? onProgress,
  }) async {
    final String partial = '${target.path}.part';
    final File temp = File(partial);
    if (await temp.exists()) {
      await temp.delete();
    }
    final List<String> failures = <String>[];
    for (final String source in <String>[url, 'https://gh-proxy.com/$url']) {
      try {
        await _downloader.download(
          source,
          partial,
          onReceiveProgress: onProgress,
          deleteOnError: true,
        );
        final File downloaded = File(partial);
        if (await downloaded.length() < 1024) {
          throw const UpdateException('下载到的文件不完整');
        }
        if (await target.exists()) {
          await target.delete();
        }
        await downloaded.rename(target.path);
        return;
      } on DioException catch (error) {
        failures.add(_shortReason(error));
      } catch (error) {
        failures.add('$error');
      }
      if (await temp.exists()) {
        await temp.delete();
      }
    }
    throw UpdateException('下载失败：${failures.join('、')}');
  }

  /// 逐段比较 x.y.z，返回 >0 表示 a 更新。
  static int _compareVersions(String a, String b) {
    final List<int> pa = _numericParts(a);
    final List<int> pb = _numericParts(b);
    for (int i = 0; i < 3; i++) {
      final int diff = pa[i].compareTo(pb[i]);
      if (diff != 0) {
        return diff;
      }
    }
    return 0;
  }

  static List<int> _numericParts(String value) {
    final List<String> segments = value.split('.');
    final List<int> out = <int>[0, 0, 0];
    for (int i = 0; i < 3 && i < segments.length; i++) {
      out[i] = int.tryParse(segments[i].trim()) ?? 0;
    }
    return out;
  }

  static String _shortReason(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时';
      case DioExceptionType.connectionError:
        return '连不上服务器';
      case DioExceptionType.badCertificate:
        return '证书校验失败';
      case DioExceptionType.badResponse:
        final int? code = error.response?.statusCode;
        return code == null ? '服务器返回异常' : 'HTTP $code';
      case DioExceptionType.cancel:
        return '已取消';
      default:
        return '网络异常';
    }
  }
}
