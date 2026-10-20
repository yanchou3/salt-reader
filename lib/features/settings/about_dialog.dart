import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/app_store.dart';
import '../../services/apk_installer.dart';
import '../../services/updater.dart';

/// 打开「关于」对话框：展示版本信息，并提供应用内更新。
Future<void> showAppAboutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => const _AboutDialog(),
  );
}

enum _Phase { idle, checking, upToDate, available, downloading, ready }

class _AboutDialog extends StatefulWidget {
  const _AboutDialog();

  @override
  State<_AboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<_AboutDialog> {
  _Phase _phase = _Phase.idle;
  UpdateInfo? _info;
  String? _savedPath;
  double _progress = 0;
  String? _progressLabel;

  bool get _isAndroid => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    // 启动时的静默检查可能已经有结果了，直接展示，省一次请求。
    final UpdateInfo? cached = AppStore.instance.availableUpdate;
    if (cached != null) {
      _info = cached;
      _phase = _Phase.available;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (BuildContext context, Widget? child) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStore store = AppStore.instance;
    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.local_activity_rounded, color: AppColors.accent),
          SizedBox(width: AppSpacing.sm),
          Text('关于'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppInfo.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '版本 ${AppInfo.versionLabel} · ${AppInfo.platformLabel}',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              _link(theme, Icons.code_rounded, '项目主页', Updater.repoUrl),
              _link(
                theme,
                Icons.new_releases_outlined,
                '发布页与历史版本',
                Updater.releasesPageUrl,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: store.autoCheckUpdate,
                onChanged: store.saveAutoCheckUpdate,
                title: const Text('自动检查更新'),
                subtitle: const Text('启动后在后台静默检查一次'),
              ),
              const Divider(height: AppSpacing.xl),
              _buildUpdateArea(theme),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: _phase == _Phase.checking || _phase == _Phase.downloading
              ? null
              : _primaryAction,
          child: Text(_primaryLabel),
        ),
      ],
    );
  }

  Widget _link(ThemeData theme, IconData icon, String label, String url) {
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateArea(ThemeData theme) {
    switch (_phase) {
      case _Phase.idle:
        return Text(
          _isAndroid
              ? '有新版本时可直接在应用内下载并安装。'
              : '有新版本时可下载压缩包，解压后覆盖原目录即可。',
          style: theme.textTheme.labelSmall,
        );
      case _Phase.checking:
        return const Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('正在检查更新…'),
          ],
        );
      case _Phase.upToDate:
        return Row(
          children: <Widget>[
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Colors.green,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '已是最新版本 ${AppInfo.version}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        );
      case _Phase.available:
        final UpdateInfo info = _info!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '发现新版本 ${info.version}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (info.publishedAt != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '发布于 ${_formatDate(info.publishedAt!)}',
                style: theme.textTheme.labelSmall,
              ),
            ],
            if (info.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: HtmlWidget(
                    md.markdownToHtml(
                      info.notes,
                      extensionSet: md.ExtensionSet.gitHubWeb,
                    ),
                    textStyle: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              _isAndroid
                  ? '将下载 APK 并调起系统安装器。'
                  : '将下载压缩包到「下载」文件夹，解压后覆盖原目录。',
              style: theme.textTheme.labelSmall,
            ),
          ],
        );
      case _Phase.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LinearProgressIndicator(
              value: _progress <= 0 ? null : _progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '正在下载 ${_progressLabel ?? ''}  '
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall,
            ),
          ],
        );
      case _Phase.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Colors.green,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('下载完成', style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _isAndroid
                  ? '点「立即安装」调起系统安装器。'
                  : '已保存到 $_savedPath，解压后覆盖原目录即可完成升级。',
              style: theme.textTheme.labelSmall,
            ),
          ],
        );
    }
  }

  String get _primaryLabel {
    switch (_phase) {
      case _Phase.idle:
        return '检查更新';
      case _Phase.checking:
        return '检查中…';
      case _Phase.upToDate:
        return '重新检查';
      case _Phase.available:
        return _isAndroid ? '下载并安装' : '下载新版本';
      case _Phase.downloading:
        return '下载中…';
      case _Phase.ready:
        return _isAndroid ? '立即安装' : '打开所在文件夹';
    }
  }

  Future<void> _primaryAction() async {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.upToDate:
        await _check();
      case _Phase.available:
        await _download();
      case _Phase.ready:
        if (_isAndroid) {
          await _install();
        } else {
          await _revealSavedFile();
        }
      case _Phase.checking:
      case _Phase.downloading:
        break;
    }
  }

  Future<void> _check() async {
    setState(() => _phase = _Phase.checking);
    final AppStore store = AppStore.instance;
    final UpdateInfo? info = await store.checkForUpdate();
    if (!mounted) {
      return;
    }
    final String? error = store.updateError;
    setState(() {
      _info = info;
      if (error != null) {
        _phase = _Phase.idle;
      } else {
        _phase = info == null ? _Phase.upToDate : _Phase.available;
      }
    });
    if (error != null) {
      _toast(error);
    }
  }

  Future<void> _download() async {
    final UpdateInfo info = _info!;
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _progressLabel = '';
    });
    try {
      final File file = _isAndroid
          ? await Updater.instance.downloadApk(info, onProgress: _onProgress)
          : await Updater.instance.downloadWindowsZip(
              info,
              onProgress: _onProgress,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _savedPath = file.path;
        _phase = _Phase.ready;
      });
      if (_isAndroid) {
        await _install();
      } else {
        _toast('已下载到 ${file.path}');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _phase = _Phase.available);
      _toast('$error');
    }
  }

  void _onProgress(int received, int total) {
    if (!mounted) {
      return;
    }
    setState(() {
      _progress = total > 0 ? received / total : 0;
      _progressLabel = total > 0 ? _sizeLabel(received, total) : '';
    });
  }

  Future<void> _install() async {
    final String? path = _savedPath;
    if (path == null) {
      return;
    }
    try {
      if (!await ApkInstaller.canInstall()) {
        if (!mounted) {
          return;
        }
        _toast('请先允许「安装未知应用」，返回后再点一次安装');
        await ApkInstaller.openInstallSettings();
        return;
      }
      await ApkInstaller.install(File(path));
    } catch (error) {
      _toast('$error');
    }
  }

  Future<void> _revealSavedFile() async {
    final String? path = _savedPath;
    if (path == null) {
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', <String>['/select,', path]);
      } else {
        await Process.run('open', <String>[File(path).parent.path]);
      }
    } catch (error) {
      _toast('打开文件夹失败：$error');
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final bool ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        _toast('打不开链接，请手动访问 $url');
      }
    } catch (error) {
      _toast('打不开链接：$error');
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  static String _sizeLabel(int received, int total) {
    String mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);
    return '${mb(received)} / ${mb(total)} MB';
  }
}
