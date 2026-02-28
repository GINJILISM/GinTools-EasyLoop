import 'package:flutter/material.dart';

import '../liquid_glass/liquid_glass_refs.dart';

Future<bool> showReplaceInputDialog(BuildContext context) async {
  final shouldReplace = await showDialog<bool>(
    context: context,
    builder: (context) {
      final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: LiquidGlassRefs.textPrimary,
            fontWeight: FontWeight.w600,
          );
      final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: LiquidGlassRefs.textSecondary,
            height: 1.4,
          );

      return AlertDialog(
        backgroundColor: LiquidGlassRefs.surfaceDeep.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: LiquidGlassRefs.outlineSoft),
        ),
        title: Text(
          '別の動画に切り替えますか？',
          style: titleStyle,
        ),
        content: Text(
          '現在の編集中セッションは新しい動画に置き換えられます。',
          style: bodyStyle,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: LiquidGlassRefs.textSecondary,
            ),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: LiquidGlassRefs.accentBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('切り替える'),
          ),
        ],
      );
    },
  );

  return shouldReplace ?? false;
}
