/// 订阅源模型。
class Feed {
  Feed({
    required this.id,
    required this.url,
    required this.title,
    this.siteUrl,
    this.group = defaultGroup,
    this.lastFetched,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 未归类的默认分组名。
  static const String defaultGroup = '未分组';

  final String id;
  final String url;
  String title;
  String? siteUrl;
  String group;
  DateTime? lastFetched;

  /// 本地最后一次修改时间，用于多端同步的 last-write-wins。
  DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'url': url,
        'title': title,
        'siteUrl': siteUrl,
        'group': group,
        'lastFetched': lastFetched?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Feed.fromJson(Map<String, dynamic> json) => Feed(
        id: json['id'] as String,
        url: json['url'] as String,
        title: (json['title'] as String?) ?? '',
        siteUrl: json['siteUrl'] as String?,
        group: (json['group'] as String?) ?? defaultGroup,
        lastFetched: json['lastFetched'] == null
            ? null
            : DateTime.tryParse(json['lastFetched'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}

/// 删除墓碑：同步时告诉其它设备「这个订阅已被删除」，避免离线设备把它复活。
class DeletedFeed {
  DeletedFeed({required this.id, required this.url, required this.deletedAt});

  final String id;
  final String url;
  final DateTime deletedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'url': url,
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory DeletedFeed.fromJson(Map<String, dynamic> json) => DeletedFeed(
        id: json['id'] as String,
        url: (json['url'] as String?) ?? '',
        deletedAt:
            DateTime.tryParse((json['deletedAt'] as String?) ?? '') ??
                DateTime.now(),
      );
}
