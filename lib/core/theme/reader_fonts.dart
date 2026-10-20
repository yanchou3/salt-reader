/// 阅读正文字体。
///
/// 三种来源：
/// - 系统默认：不注册字体族（[isSystem]）
/// - 内置可下载字体：[sources] 非空，首次使用时按顺序尝试下载并缓存到应用目录
/// - 用户本地导入：[isCustom]，选中时从本地文件注册
class ReaderFont {
  const ReaderFont({
    required this.id,
    required this.label,
    this.sources = const <String>[],
    this.sizeHint,
    this.isSystem = false,
    this.isCustom = false,
  });

  final String id;
  final String label;

  /// 内置字体的下载地址，按「国内镜像 → 海外代理」的顺序排列，逐个尝试。
  final List<String> sources;

  /// 下载体积的粗略提示，仅用于界面文案。
  final String? sizeHint;

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
  ///
  /// 前四个是国内 CTAN 镜像（华为云 / 上海交大 / 南京大学），
  /// 实测都能在 Dart 的 HTTP 栈里正常下载且速度明显好于 GitHub。
  /// 注意：清华 mirror 会对非浏览器 TLS 指纹直接返回 403，故不采用。
  static const ReaderFont notoSerifSc = ReaderFont(
    id: 'noto_serif_sc',
    label: '思源宋体',
    sizeHint: '约 23 MB',
    sources: <String>[
      'https://repo.huaweicloud.com/artifactory/CTAN-local/fonts/notocjksc/'
          'NotoSerifCJKsc-Regular.otf',
      'https://mirrors.huaweicloud.com/CTAN/fonts/notocjksc/'
          'NotoSerifCJKsc-Regular.otf',
      'https://mirrors.sjtug.sjtu.edu.cn/ctan/fonts/notocjksc/'
          'NotoSerifCJKsc-Regular.otf',
      'https://mirrors.nju.edu.cn/CTAN/fonts/notocjksc/'
          'NotoSerifCJKsc-Regular.otf',
      'https://gh-proxy.com/https://github.com/notofonts/noto-cjk/raw/'
          'main/Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf',
    ],
  );

  /// 霞鹜文楷 Lite（SIL OFL 开源）。国内镜像提供的是国标 Lite 版。
  static const ReaderFont lxgwWenKai = ReaderFont(
    id: 'lxgw_wenkai',
    label: '霞鹜文楷',
    sizeHint: '约 13 MB',
    sources: <String>[
      'https://repo.huaweicloud.com/artifactory/CTAN-local/fonts/lxgw-fonts/'
          'LXGWWenKaiGBLite-Regular.ttf',
      'https://mirrors.huaweicloud.com/CTAN/fonts/lxgw-fonts/'
          'LXGWWenKaiGBLite-Regular.ttf',
      'https://mirrors.sjtug.sjtu.edu.cn/ctan/fonts/lxgw-fonts/'
          'LXGWWenKaiGBLite-Regular.ttf',
      'https://mirrors.nju.edu.cn/CTAN/fonts/lxgw-fonts/'
          'LXGWWenKaiGBLite-Regular.ttf',
      'https://gh-proxy.com/https://github.com/lxgw/LxgwWenKai-Lite/'
          'releases/latest/download/LXGWWenKaiLite-Regular.ttf',
    ],
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
