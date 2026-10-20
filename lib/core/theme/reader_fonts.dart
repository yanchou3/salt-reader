/// 阅读正文字体。
///
/// 三种来源：
/// - 系统默认：不注册字体族（[isSystem]）
/// - 内置可下载字体：[url] 非空，首次使用时下载并缓存到应用目录
/// - 用户本地导入：[isCustom]，选中时从本地文件注册
class ReaderFont {
  const ReaderFont({
    required this.id,
    required this.label,
    this.url,
    this.isSystem = false,
    this.isCustom = false,
  });

  final String id;
  final String label;

  /// 内置字体的下载地址（为空表示需要本地文件或系统默认）。
  final String? url;
  final bool isSystem;
  final bool isCustom;

  /// 注册到 Flutter 的字体族名；系统默认返回 null。
  String? get family => isSystem ? null : 'reader_font_$id';

  static const ReaderFont system = ReaderFont(
    id: 'system',
    label: '系统默认',
    isSystem: true,
  );

  /// 思源宋体（Source Han Serif / Noto Serif CJK SC，OFL 开源）。
  static const ReaderFont notoSerifSc = ReaderFont(
    id: 'noto_serif_sc',
    label: '思源宋体',
    url: 'https://ghproxy.net/https://github.com/notofonts/noto-cjk/raw/'
        'main/Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf',
  );

  /// 霞鹜文楷 Lite（SIL OFL 开源）。
  static const ReaderFont lxgwWenKai = ReaderFont(
    id: 'lxgw_wenkai',
    label: '霞鹜文楷',
    url: 'https://ghproxy.net/https://github.com/lxgw/LxgwWenKai-Lite/'
        'releases/latest/download/LXGWWenKaiLite-Regular.ttf',
  );

  /// 内置字体列表（含系统默认）。
  static const List<ReaderFont> builtIn = <ReaderFont>[
    system,
    notoSerifSc,
    lxgwWenKai,
  ];

  /// 按 id 查字体，找不到就回退到系统默认。
  static ReaderFont byId(String? id, List<ReaderFont> custom) {
    if (id == null || id.isEmpty) {
      return system;
    }
    for (final ReaderFont font in builtIn) {
      if (font.id == id) {
        return font;
      }
    }
    for (final ReaderFont font in custom) {
      if (font.id == id) {
        return font;
      }
    }
    return system;
  }

  /// 自定义字体的持久化表示（字体文件按 id 存放在应用目录）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
      };

  static ReaderFont fromJson(Map<String, dynamic> json) => ReaderFont(
        id: (json['id'] as String?) ?? '',
        label: (json['label'] as String?) ?? '自定义字体',
        isCustom: true,
      );
}
