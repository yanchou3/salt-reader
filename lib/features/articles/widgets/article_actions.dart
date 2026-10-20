import 'package:flutter/material.dart';

import '../../../core/widgets/glass.dart';
import '../../../data/app_store.dart';
import '../../../data/models/article.dart';

/// 长按文章卡片时的快捷操作（标记已读 / 收藏）。
Future<void> showArticleActions(BuildContext context, Article article) async {
  final AppStore store = AppStore.instance;
  await showGlassSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(
                article.read ? Icons.undo_rounded : Icons.done_rounded,
              ),
              title: Text(article.read ? '标记为未读' : '标记为已读'),
              onTap: () {
                store.setRead(article, !article.read);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: Icon(
                article.starred
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
              title: Text(article.starred ? '取消收藏' : '收藏'),
              onTap: () {
                store.toggleStar(article);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}
