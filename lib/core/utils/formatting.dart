/// 时间与文本的展示格式化。
library;

/// 相对时间（刚刚 / N 分钟前 / N 小时前 / N 天前 / 日期）。
String relativeTime(DateTime? time) {
  if (time == null) {
    return '';
  }
  final DateTime now = DateTime.now();
  final Duration diff = now.difference(time);
  if (diff.isNegative || diff.inMinutes < 1) {
    return '刚刚';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} 分钟前';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} 小时前';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays} 天前';
  }
  return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
}

/// 去掉 HTML 标签与常见实体，得到用于列表摘要的纯文本。
String stripHtml(String html) {
  if (html.isEmpty) {
    return '';
  }
  final String text = html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
  return text.trim();
}
