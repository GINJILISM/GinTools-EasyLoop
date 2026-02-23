import 'package:flutter/material.dart';

Future<bool> showReplaceInputDialog(BuildContext context) async {
  final shouldReplace = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('別の動画に切り替えますか？'),
        content: const Text('現在の編集中セッションは新しい動画に置き換えられます。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('切り替える'),
          ),
        ],
      );
    },
  );

  return shouldReplace ?? false;
}
