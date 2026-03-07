import 'package:flutter/material.dart';

import '../../design/typography/app_font_roles.dart';
import '../liquid_glass/liquid_glass_refs.dart';
import '../app_strings.dart';

Future<bool> showReplaceInputDialog(BuildContext context) async {
  final shouldReplace = await showDialog<bool>(
    context: context,
    builder: (context) {
      final titleStyle = AppFontRoles.dialogTitle(
        Theme.of(context).textTheme.headlineSmall,
      )?.copyWith(
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
          AppStrings.replaceVideoTitle,
          style: titleStyle,
        ),
        content: Text(
          AppStrings.replaceVideoDescription,
          style: bodyStyle,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: LiquidGlassRefs.textSecondary,
              textStyle: AppFontRoles.actionButtonLabel(
                Theme.of(context).textTheme.labelLarge,
              ),
            ),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: LiquidGlassRefs.accentBlue,
              foregroundColor: Colors.white,
              textStyle: AppFontRoles.actionButtonLabel(
                Theme.of(context).textTheme.labelLarge,
              ),
            ),
            child: const Text(AppStrings.replace),
          ),
        ],
      );
    },
  );

  return shouldReplace ?? false;
}
