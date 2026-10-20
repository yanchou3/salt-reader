import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 文章配图的磁盘缓存。
///
/// 阅读页的图片都走 `HeaderNetworkImage`：这里把下载成功的图片按 URL 落盘，
/// 再次打开同一篇文章时直接读本地，让「点开即看」在图片上也成立，
/// 已读过的文章离线也能看到配图。
///
/// 缓存属于「有更好、没有也能读」的附加能力：所有 IO 吞异常，
/// 读写失败一律当作未命中，绝不把错误抛进图片加载链路。
class ImageDiskCache {
  ImageDiskCache._();

  static final ImageDiskCache instance = ImageDiskCache._();

  /// 缓存目录总容量上限；超出后按最后访问时间淘汰到 80%，避免频繁清理。
  static const int maxBytes = 128 * 1024 * 1024;

  /// 单张图片超过这个大小就不缓存（多为超大图，性价比低且拖慢淘汰）。
  static const int _maxEntryBytes = 8 * 1024 * 1024;

  Directory? _cachedDir;

  /// 已知的缓存占用；未知（未统计过）时为 null，写满上限时才走一次全量统计。
  int? _totalBytes;

  /// 串行化写入与淘汰，避免并发遍历/删除同一批文件。
  Future<void> _chain = Future<void>.value();

  Future<Directory> _dir() async {
    final Directory? cached = _cachedDir;
    if (cached != null) {
      return cached;
    }
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(
      '${base.path}${Platform.pathSeparator}image_cache',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir;
    return dir;
  }

  Future<File> _fileFor(String url) async {
    final Directory dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}${_keyOf(url)}.img');
  }

  /// 读取缓存字节；未命中、内容损坏或读失败时返回 null。
  Future<Uint8List?> read(String url) async {
    try {
      final File file = await _fileFor(url);
      if (!await file.exists()) {
        return null;
      }
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        await _delete(file);
        return null;
      }
      // 刷新「最后访问时间」，淘汰时据此保留最近还在看的图。
      unawaited(file.setLastModified(DateTime.now()));
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// 写入缓存。不阻塞调用方：落盘在后台完成，失败静默。
  void save(String url, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxEntryBytes) {
      return;
    }
    unawaited(
      _serialize(() async {
        try {
          final File file = await _fileFor(url);
          await file.writeAsBytes(bytes, flush: false);
          final int? total = _totalBytes;
          if (total != null) {
            _totalBytes = total + bytes.length;
          }
          if (_totalBytes == null || _totalBytes! > maxBytes) {
            await _trim();
          }
        } catch (_) {}
      }),
    );
  }

  /// 删掉某个 URL 的缓存（例如读出来解码失败，说明这份缓存坏了）。
  Future<void> remove(String url) async {
    try {
      await _delete(await _fileFor(url));
    } catch (_) {}
  }

  /// 当前缓存占用（字节），用于设置页展示。
  Future<int> size() async {
    try {
      final Directory dir = await _dir();
      int total = 0;
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      _totalBytes = total;
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 清空缓存。
  Future<void> clear() async {
    await _serialize(() async {
      try {
        final Directory dir = await _dir();
        await for (final FileSystemEntity entity in dir.list()) {
          await _delete(entity);
        }
        _totalBytes = 0;
      } catch (_) {}
    });
  }

  Future<void> _trim() async {
    try {
      final Directory dir = await _dir();
      final List<File> files = <File>[];
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }
      final List<ImageCacheEntry> entries = <ImageCacheEntry>[];
      for (final File file in files) {
        try {
          final FileStat stat = await file.stat();
          entries.add(ImageCacheEntry(file, stat.size, stat.modified));
        } catch (_) {}
      }
      entries.sort(
        (ImageCacheEntry a, ImageCacheEntry b) =>
            a.modified.compareTo(b.modified),
      );
      int total = 0;
      for (final ImageCacheEntry entry in entries) {
        total += entry.size;
      }
      final int target = (maxBytes * 0.8).round();
      for (final ImageCacheEntry entry in entries) {
        if (total <= target) {
          break;
        }
        await _delete(entry.file);
        total -= entry.size;
      }
      _totalBytes = total;
    } catch (_) {}
  }

  Future<void> _delete(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete();
      }
    } catch (_) {}
  }

  Future<void> _serialize(Future<void> Function() task) {
    final Future<void> result = _chain.then((_) => task());
    _chain = result;
    return result;
  }

  /// URL → 文件名：FNV-1a 双种子拼成 64 位，避免碰撞把两张图混成一张。
  static String _keyOf(String url) {
    int a = 0x811c9dc5;
    int b = 0x9dc5811c;
    for (int i = 0; i < url.length; i++) {
      final int unit = url.codeUnitAt(i);
      a = ((a ^ unit) * 0x01000193) & 0xFFFFFFFF;
      b = ((b + unit) * 0x85ebca6b) & 0xFFFFFFFF;
    }
    return '${a.toRadixString(16).padLeft(8, '0')}'
        '${b.toRadixString(16).padLeft(8, '0')}';
  }
}

/// 淘汰时用的文件快照。
class ImageCacheEntry {
  ImageCacheEntry(this.file, this.size, this.modified);

  final File file;
  final int size;
  final DateTime modified;
}