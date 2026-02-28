import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../liquid_glass/liquid_glass_refs.dart';

class LiquidGlassActionButton extends StatelessWidget {
  const LiquidGlassActionButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.primary = false,
    this.fillColor,
    this.foregroundColor,
    this.borderColor,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final ButtonStyle? style;
  final bool primary;
  final Color? fillColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final useLiquidGlass = LiquidGlassRefs.supportsLiquidGlass;
    final isWindowsPlatform = LiquidGlassRefs.isWindowsPlatform;
    final enabled = onPressed != null;
    final colorScheme = Theme.of(context).colorScheme;

    final resolvedForegroundColor = foregroundColor ??
        (primary ? colorScheme.primary : colorScheme.onSurface);

    if (!useLiquidGlass) {
      if (primary) {
        return FilledButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: label,
          style: style ??
              FilledButton.styleFrom(
                backgroundColor: fillColor,
                foregroundColor: resolvedForegroundColor,
                side: borderColor != null
                    ? BorderSide(color: borderColor!)
                    : null,
              ),
        );
      }
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: label,
        style: style ??
            OutlinedButton.styleFrom(
              backgroundColor: fillColor,
              foregroundColor: resolvedForegroundColor,
              side:
                  borderColor != null ? BorderSide(color: borderColor!) : null,
            ),
      );
    }

    final fg = resolvedForegroundColor;
    final disabledFg = colorScheme.onSurface.withValues(alpha: 0.45);

    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(LiquidGlassRefs.exportButtonRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1)
            : null,
      ),
      child: SizedBox(
        height: LiquidGlassRefs.exportButtonHeight,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius:
                BorderRadius.circular(LiquidGlassRefs.exportButtonRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LiquidGlassRefs.exportButtonHorizontalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconTheme(
                    data: IconThemeData(color: enabled ? fg : disabledFg),
                    child: icon,
                  ),
                  const SizedBox(width: 8),
                  DefaultTextStyle(
                    style: TextStyle(
                      color: enabled ? fg : disabledFg,
                      fontWeight: FontWeight.w600,
                    ),
                    child: label,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final glassButton = LiquidGlass.withOwnLayer(
      settings: isWindowsPlatform
          ? LiquidGlassRefs.exportButtonLayerSettingsWindows
          : LiquidGlassRefs.exportButtonLayerSettings,
      shape: const LiquidRoundedSuperellipse(
        borderRadius: LiquidGlassRefs.exportButtonRadius,
      ),
      child: isWindowsPlatform
          ? child
          : GlassGlow(
              glowColor: primary ? Colors.white30 : Colors.white24,
              glowRadius: primary ? 0.9 : 0.7,
              child: child,
            ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: LiquidStretch(
        stretch: isWindowsPlatform
            ? LiquidGlassRefs.exportButtonStretchWindows
            : LiquidGlassRefs.exportButtonStretch,
        interactionScale: isWindowsPlatform
            ? LiquidGlassRefs.exportButtonInteractionScaleWindows
            : LiquidGlassRefs.exportButtonInteractionScale,
        child: glassButton,
      ),
    );
  }
}
