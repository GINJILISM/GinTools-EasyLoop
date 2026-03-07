import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../liquid_glass/liquid_glass_refs.dart';

/// Reusable circular icon button that can render with Liquid Glass.
class InteractiveLiquidGlassIconButton extends StatelessWidget {
  const InteractiveLiquidGlassIconButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.isDisabled,
    required this.onPressed,
    required this.useLiquidGlass,
    this.grouped = false,
    this.isPrimary = false,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    super.key,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final bool isDisabled;
  final VoidCallback onPressed;
  final bool useLiquidGlass;
  final bool grouped;
  final bool isPrimary;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final isWindowsPlatform = LiquidGlassRefs.isWindowsPlatform;
    final colorScheme = Theme.of(context).colorScheme;
    final disabledColor = colorScheme.onSurface.withValues(alpha: 0.45);
    final iconColor = foregroundColor ??
        (isPrimary ? colorScheme.primary : colorScheme.onSurface);
    final resolvedBackgroundColor = backgroundColor ??
        (isPrimary
            ? colorScheme.primaryContainer.withValues(alpha: 0.9)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.75));
    final resolvedDisabledBackgroundColor = disabledBackgroundColor ??
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final buttonSize = isPrimary
        ? LiquidGlassRefs.transportPrimaryButtonSize
        : LiquidGlassRefs.transportButtonSize;

    if (!useLiquidGlass) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          key: buttonKey,
          onPressed: isDisabled ? null : onPressed,
          icon: Icon(icon, size: isPrimary ? 24 : 20),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: Size.square(buttonSize),
            fixedSize: Size.square(buttonSize),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const CircleBorder(),
            backgroundColor: resolvedBackgroundColor,
            disabledBackgroundColor: resolvedDisabledBackgroundColor,
            foregroundColor: iconColor,
            disabledForegroundColor: disabledColor,
          ),
        ),
      );
    }

    final iconButton = SizedBox.square(
      dimension: buttonSize,
      child: IconButton(
        key: buttonKey,
        onPressed: isDisabled ? null : onPressed,
        icon: Icon(icon, size: isPrimary ? 24 : 20),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          minimumSize: Size.square(buttonSize),
          fixedSize: Size.square(buttonSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: iconColor,
          disabledForegroundColor: disabledColor,
        ),
      ),
    );

    final liquidContent = DecoratedBox(
      decoration: BoxDecoration(
        color: isDisabled
            ? resolvedDisabledBackgroundColor
            : resolvedBackgroundColor,
        shape: BoxShape.circle,
      ),
      child: iconButton,
    );

    final child = isWindowsPlatform
        ? liquidContent
        : GlassGlow(
            glowColor: isPrimary
                ? const Color.fromARGB(168, 255, 255, 255)
                : LiquidGlassRefs.buttonSecondaryGlowColor,
            glowRadius: isPrimary
                ? LiquidGlassRefs.buttonPrimaryGlowRadius
                : LiquidGlassRefs.buttonSecondaryGlowRadius,
            child: liquidContent,
          );

    final glass = grouped
        ? LiquidGlass.grouped(
            shape: const LiquidOval(),
            child: child,
          )
        : LiquidGlass.withOwnLayer(
            settings: LiquidGlassRefs.isWindowsPlatform
                ? LiquidGlassRefs.loopTabsLayerSettingsWindows
                : LiquidGlassRefs.loopTabsLayerSettings,
            shape: const LiquidOval(),
            child: child,
          );

    return Tooltip(
      message: tooltip,
      child: LiquidStretch(
        stretch: isWindowsPlatform
            ? LiquidGlassRefs.buttonStretchWindows
            : LiquidGlassRefs.buttonStretch,
        interactionScale: isWindowsPlatform
            ? LiquidGlassRefs.buttonInteractionScaleWindows
            : LiquidGlassRefs.buttonInteractionScale,
        child: glass,
      ),
    );
  }
}
