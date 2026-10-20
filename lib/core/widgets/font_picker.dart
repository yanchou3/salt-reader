import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../services/font_library.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/reader_fonts.dart';
import 'glass.dart';

/// 字体选择列表：系统默认 + 内置可下载字体 + 本地导入字体。
///
/// 阅读页快捷面板与设置页共用，负责选字体、下载进度、添加 / 删除本地字体。
class FontPicker extends StatelessWidget {
  const FontPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (BuildContext context, Widget? child) {
        final AppStore store = AppStore.instance;
        final List<ReaderFont> fonts = <ReaderFont>[
          ...ReaderFont.builtIn,
          ...store.customFonts,
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final ReaderFont font in fonts) _tile(context, store, font),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: store.loadingFontId != null
                    ? null
                    : () => _pickLocalFile(context, store),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加本地字体'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, AppStore store, ReaderFont font) {
    final ThemeData theme = Theme.of(context);
    final bool selected = store.readerFont.id == font.id;
    final bool loading = store.loadingFontId == font.id;
    final bool ready = FontLibrary.instance.isRegistered(font);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 20,
        color: selected ? AppColors.accent : theme.colorScheme.outline,
      ),
      title: Text(
        font.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: ready ? font.family : null),
      ),
      subtitle: Text(
        loading
            ? '${store.fontSource ?? '国内镜像'}下载中 '
                '${(store.fontProgress * 100).toStringAsFixed(0)}%'
            : _subtitle(font, ready),
        style: theme.textTheme.labelSmall,
      ),
      trailing: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (font.isCustom
              ? IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: '删除字体',
                  onPressed: () => _confirmDelete(context, store, font),
                )
              : null),
      onTap: loading ? null : () => _select(context, store, font),
    );
  }

  Future<void> _select(
    BuildContext context,
    AppStore store,
    ReaderFont font,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await store.selectFont(font);
    if (ok) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(store.lastError ?? '「${font.label}」加载失败'),
        action: SnackBarAction(
          label: '重试',
          onPressed: () => store.selectFont(font),
        ),
      ),
    );
  }

  static String _subtitle(ReaderFont font, bool ready) {
    if (font.isSystem) {
      return '跟随系统字体';
    }
    if (font.isCustom) {
      return ready ? '本地字体' : '文件缺失';
    }
    if (ready) {
      return '已下载，可离线使用';
    }
    final String size =
        font.sizeHint == null ? '' : '，${font.sizeHint}';
    return '首次选择时联网下载（国内镜像$size）';
  }

  Future<void> _pickLocalFile(BuildContext context, AppStore store) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: '选择字体文件',
        type: FileType.custom,
        allowedExtensions: <String>['ttf', 'otf', 'ttc'],
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('打开文件选择器失败：$error')));
      return;
    }
    if (picked == null) {
      return;
    }
    final String label = picked.name.replaceAll(
      RegExp(r'\.(ttf|otf|ttc)$', caseSensitive: false),
      '',
    );
    final bool ok;
    try {
      ok = await store.addLocalFont(await picked.readAsBytes(), label);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('读取字体文件失败：$error')));
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? '已导入「$label」' : (store.lastError ?? '导入失败'))),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppStore store,
    ReaderFont font,
  ) async {
    final bool? confirmed = await showGlassDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => GlassDialog(
        title: const Text('删除字体'),
        content: Text('确定删除「${font.label}」吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await store.removeLocalFont(font);
    }
  }
}
