import '../../core/utils/formatting.dart';

/// 文章模型。
class Article {
  Article({
    required this.id,
    required this.feedId,
    required this.feedTitle,
    required this.title,
    this.link,
    this.body = '',
    this.published,
    this.read = false,
    this.starred = false,
  });

  final String id;
  final String feedId;
  final String feedTitle;
  final String title;
  final String? link;
  final DateTime? published;
  bool read;
  bool starred;

  /// 正文（HTML）。抓取「阅读模式」全文后会更新，改完记得调用 [updateBody]。
  String body;

  String? _summaryCache;

  /// 列表用的纯文本摘要：首次访问时计算并缓存，避免每帧跑正则。
  String get summary => _summaryCache ??= stripHtml(body);

  /// 更新正文并使摘要缓存失效。
  void updateBody(String value) {
    body = value;
    _summaryCache = null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'feedId': feedId,
        'feedTitle': feedTitle,
        'title': title,
        'link': link,
        'body': body,
        'published': published?.toIso8601String(),
        'read': read,
        'starred': starred,
      };

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as String,
        feedId: (json['feedId'] as String?) ?? '',
        feedTitle: (json['feedTitle'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        link: json['link'] as String?,
        body: (json['body'] as String?) ?? '',
        published: json['published'] == null
            ? null
            : DateTime.tryParse(json['published'] as String),
        read: (json['read'] as bool?) ?? false,
        starred: (json['starred'] as bool?) ?? false,
      );
}
