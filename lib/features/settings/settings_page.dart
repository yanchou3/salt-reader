import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/font_picker.dart';
import '../../core/widgets/glass.dart';
import '../../data/app_store.dart';
import '../../services/image_cache.dart';
import '../../services/opml_service.dart';
import '../../services/window_backdrop.dart';
import 'about_dialog.dart';

/// 设置页：阅读偏好、OPML 导入导出、同步（部分待实现）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: AppStore.instance,
          builder: (BuildContext context, Widget? child) {
            final AppStore store = AppStore.instance;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.navBottom,
              ),
              children: <Widget>[
                Text('设置', style: theme.textTheme.displaySmall),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('阅读'),
                _GlassGroup(
                  children: <Widget>[
                    _SettingTile(
                      icon: Icons.text_fields_rounded,
                      title: '阅读排版',
                      subtitle:
                          '${store.readerFont.label} · 字号 ${store.readerFontScale.toStringAsFixed(2)}× · 行距 ${store.readerLineHeight.toStringAsFixed(1)} · 栏宽 ${store.readerMaxWidth.round()}',
                      onTap: () => _showReaderPrefsDialog(context, store),
                    ),
                    _SettingTile(
                      icon: Icons.brightness_6_outlined,
                      title: '外观',
                      subtitle: _themeModeLabel(store.themeMode),
                      onTap: () => _showThemeDialog(context, store),
                    ),
                    if (Platform.isWindows && WindowBackdrop.supported)
                      SwitchListTile(
                        secondary: const Icon(Icons.blur_on_rounded),
                        title: const Text('窗口透出桌面'),
                        subtitle:
                            const Text('Windows 11 的 Mica 背景；关掉可再省一点显卡开销'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        value: store.micaEnabled,
                        onChanged: store.saveMicaEnabled,
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.download_rounded),
                      title: const Text('自动抓取全文'),
                      subtitle: const Text('刷新后后台预抓只有摘要的文章，点开即见全文'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      value: store.autoFetchFullText,
                      onChanged: store.saveAutoFetchFullText,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('数据'),
                _GlassGroup(
                  children: <Widget>[
                    _SettingTile(
                      icon: Icons.file_download_outlined,
                      title: '导入 OPML',
                      subtitle: '从其它阅读器迁移订阅',
                      onTap: store.loading
                          ? null
                          : () => _importOpml(context, store),
                    ),
                    _SettingTile(
                      icon: Icons.file_upload_outlined,
                      title: '导出 OPML',
                      subtitle: store.hasFeeds
                          ? '导出 ${store.feeds.length} 个订阅源'
                          : '暂无订阅源',
                      onTap: store.hasFeeds
                          ? () => _exportOpml(context, store)
                          : null,
                    ),
                    _SettingTile(
                      icon: Icons.image_outlined,
                      title: '图片缓存',
                      subtitle: '文章配图缓存到本机，重复阅读更快、可离线看',
                      onTap: () => _showImageCacheDialog(context),
                    ),
                    _SettingTile(
                      icon: Icons.cloud_outlined,
                      title: 'WebDAV 服务器',
                      subtitle: store.webdavConfigured
                          ? (store.webdavUrl ?? '')
                          : '未配置（坚果云 dav.jianguoyun.com）',
                      onTap: () => _showWebDavDialog(context, store),
                    ),
                    _SettingTile(
                      icon: Icons.sync_rounded,
                      title: '立即同步',
                      subtitle: store.webdavConfigured
                          ? '双向同步订阅与已读 / 收藏'
                          : '配置后可同步',
                      onTap: store.webdavConfigured && !store.loading
                          ? () => _runSync(context, store)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('关于'),
                _GlassGroup(
                  children: <Widget>[
                    _SettingTile(
                      icon: Icons.info_outline_rounded,
                      title: '关于${AppInfo.name}',
                      subtitle: store.availableUpdate == null
                          ? '版本 ${AppInfo.versionLabel} · 检查更新'
                          : '发现新版本 ${store.availableUpdate!.version} · 点此更新',
                      onTap: () => showAppAboutDialog(context),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  static Future<void> _showThemeDialog(
    BuildContext context,
    AppStore store,
  ) async {
    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => GlassDialog(
        title: const Text('外观'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _themeOption(dialogContext, store, ThemeMode.system, '跟随系统'),
            _themeOption(dialogContext, store, ThemeMode.light, '浅色'),
            _themeOption(dialogContext, store, ThemeMode.dark, '深色'),
          ],
        ),
      ),
    );
  }

  static Widget _themeOption(
    BuildContext dialogContext,
    AppStore store,
    ThemeMode mode,
    String label,
  ) {
    final bool selected = store.themeMode == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.accent)
          : null,
      onTap: () {
        store.saveThemeMode(mode);
        Navigator.of(dialogContext).pop();
      },
    );
  }

  static Future<void> _showReaderPrefsDialog(
    BuildContext context,
    AppStore store,
  ) async {
    double fontScale = store.readerFontScale;
    double lineHeight = store.readerLineHeight;
    double maxWidth = store.readerMaxWidth;

    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) {
          final ThemeData theme = Theme.of(context);
          return GlassDialog(
            title: const Text('阅读排版'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('预览', style: theme.textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.sm),
                    ListenableBuilder(
                      listenable: AppStore.instance,
                      builder: (BuildContext context, Widget? child) => Text(
                        '阅读工具的价值，不在于让你读得更多，而在于让你读得更从容。',
                        style: TextStyle(
                          fontSize: 16 * fontScale,
                          height: lineHeight,
                          fontFamily: AppStore.instance.activeFontFamily,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('字体', style: theme.textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    const FontPicker(),
                    const SizedBox(height: AppSpacing.md),
                    _prefSlider(
                      '字号',
                      fontScale,
                      0.8,
                      1.6,
                      (double v) => setLocal(() => fontScale = v),
                    ),
                    _prefSlider(
                      '行距',
                      lineHeight,
                      1.3,
                      2.2,
                      (double v) => setLocal(() => lineHeight = v),
                    ),
                    _prefSlider(
                      '栏宽',
                      maxWidth,
                      480,
                      1000,
                      (double v) => setLocal(() => maxWidth = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  await store.saveReaderPrefs(
                    fontScale: fontScale,
                    lineHeight: lineHeight,
                    maxWidth: maxWidth,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _prefSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label  ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13),
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  static Future<void> _showWebDavDialog(
    BuildContext context,
    AppStore store,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final TextEditingController urlController = TextEditingController(
      text: store.webdavUrl ?? 'https://dav.jianguoyun.com/dav/',
    );
    final TextEditingController userController =
        TextEditingController(text: store.webdavUser ?? '');
    final TextEditingController passController =
        TextEditingController(text: store.webdavPassword ?? '');

    final bool? saved = await showGlassDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => GlassDialog(
        title: const Text('坚果云 WebDAV'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  helperText: '坚果云：https://dav.jianguoyun.com/dav/',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: userController,
                decoration: const InputDecoration(
                  labelText: '账号（注册邮箱）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '第三方应用密码',
                  helperText: '坚果云「安全选项 → 第三方应用管理」里生成',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (saved != true) {
      return;
    }
    await store.saveWebDav(
      url: urlController.text.trim(),
      user: userController.text.trim(),
      password: passController.text,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('WebDAV 配置已保存')),
    );
  }

  static Future<void> _runSync(BuildContext context, AppStore store) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在同步…')));
    final String result = await store.syncNow();
    messenger.showSnackBar(SnackBar(content: Text(result)));
  }

  /// 图片缓存：展示占用大小，并可一键清空。
  static Future<void> _showImageCacheDialog(BuildContext context) async {
    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _ImageCacheDialog(),
    );
  }

  static Future<void> _importOpml(BuildContext context, AppStore store) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final PlatformFile? picked = await FilePicker.pickFile(
        dialogTitle: '选择 OPML 文件',
        type: FileType.custom,
        allowedExtensions: <String>['opml', 'xml'],
      );
      if (picked == null) {
        return;
      }
      final Uint8List bytes = await picked.readAsBytes();
      final List<OpmlEntry> entries =
          OpmlService.parse(utf8.decode(bytes, allowMalformed: true));
      if (entries.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('这个 OPML 里没有找到订阅源')),
        );
        return;
      }
      final int added = await store.importFeeds(entries);
      messenger.showSnackBar(
        SnackBar(content: Text('导入完成：新增 $added 个订阅源')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  static Future<void> _exportOpml(BuildContext context, AppStore store) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String opml = OpmlService.build(store.feeds);
      final Uri? saved = await FilePicker.saveFile(
        dialogTitle: '导出 OPML',
        fileName: 'rss-reader.opml',
        mimeType: 'text/x-opml',
        bytes: Uint8List.fromList(utf8.encode(opml)),
      );
      if (saved == null) {
        return;
      }
      final String location =
          saved.scheme == 'file' ? saved.toFilePath() : saved.toString();
      messenger.showSnackBar(SnackBar(content: Text('已导出到 $location')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 0.6),
      ),
    );
  }
}

/// 设置分组：一块玻璃面板，把同组条目包在一起。
class _GlassGroup extends StatelessWidget {
  const _GlassGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      // 面板背后是静态的极光底，不需要每帧重新采样模糊；
      // 半透明底色本身已经足够「玻璃」。
      blur: false,
      // 大半径柔影在集显上要逐帧模糊，切到设置页会明显卡一下；
      // 这里的底色已经能勾出边界，去掉投影几乎看不出差别。
      showShadow: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// 图片缓存对话框：显示占用大小与上限，可清空。
class _ImageCacheDialog extends StatefulWidget {
  @override
  State<_ImageCacheDialog> createState() => _ImageCacheDialogState();
}

class _ImageCacheDialogState extends State<_ImageCacheDialog> {
  int? _bytes;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int bytes = await ImageDiskCache.instance.size();
    if (mounted) {
      setState(() => _bytes = bytes);
    }
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    await ImageDiskCache.instance.clear();
    final int bytes = await ImageDiskCache.instance.size();
    if (!mounted) {
      return;
    }
    setState(() {
      _clearing = false;
      _bytes = bytes;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清空图片缓存')),
    );
  }

  static String _format(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? bytes = _bytes;
    final String sizeText = bytes == null ? '正在统计…' : _format(bytes);
    return GlassDialog(
      title: const Text('图片缓存'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('已用 $sizeText', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '阅读文章时用到的配图会缓存到本机，重看时无需再等下载，'
            '没网也能看到。超出 ${_format(ImageDiskCache.maxBytes)} 后会自动清理最久未看的。',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _clearing ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        TextButton(
          onPressed: (_clearing || (bytes ?? 0) == 0) ? null : _clear,
          child: Text(_clearing ? '清理中…' : '清空缓存'),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      enabled: onTap != null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
      ),
      subtitle: Text(subtitle, style: theme.textTheme.labelSmall),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}
