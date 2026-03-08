import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../liquid_glass/liquid_glass_refs.dart';

/// Reusable icon button with embossed depth and optional Liquid Glass behavior.
class InteractiveLiquidGlassIconButton extends StatefulWidget {
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
  State<InteractiveLiquidGlassIconButton> createState() =>
      _InteractiveLiquidGlassIconButtonState();
}

class _InteractiveLiquidGlassIconButtonState
    extends State<InteractiveLiquidGlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isWindowsPlatform = LiquidGlassRefs.isWindowsPlatform;
    final colorScheme = Theme.of(context).colorScheme;
    final disabledColor = colorScheme.onSurface.withValues(alpha: 0.45);
    final iconColor = widget.foregroundColor ??
        (widget.isPrimary ? colorScheme.primary : colorScheme.onSurface);
    final resolvedBackgroundColor = widget.backgroundColor ??
        (widget.isPrimary
            ? colorScheme.primaryContainer.withValues(alpha: 0.9)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.75));
    final resolvedDisabledBackgroundColor = widget.disabledBackgroundColor ??
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final buttonSize = widget.isPrimary
        ? LiquidGlassRefs.transportPrimaryButtonSize
        : LiquidGlassRefs.transportButtonSize;

    final pressDepth = isWindowsPlatform
        ? LiquidGlassRefs.buttonPressDepthWindows
        : LiquidGlassRefs.buttonPressDepth;

    final buttonFace = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(
        0,
        widget.isDisabled ? 0 : (_isPressed ? pressDepth : 0),
        0,
      ),
      child: _EmbossedButtonFace(
        size: buttonSize,
        isDisabled: widget.isDisabled,
        isPressed: _isPressed,
        icon: widget.icon,
        iconColor: iconColor,
        disabledIconColor: disabledColor,
        backgroundColor: resolvedBackgroundColor,
        disabledBackgroundColor: resolvedDisabledBackgroundColor,
        buttonKey: widget.buttonKey,
        onPressed: widget.onPressed,
        onHighlightChanged: (pressed) {
          if (widget.isDisabled || pressed == _isPressed) {
            return;
          }
          setState(() => _isPressed = pressed);
        },
      ),
    );

    final shell = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LiquidGlassRefs.buttonEmbossRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: _isPressed ? 0.18 : 0.28),
            Colors.black.withValues(alpha: _isPressed ? 0.16 : 0.22),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isPressed ? 0.08 : 0.16),
            blurRadius: _isPressed ? 5 : 10,
            offset: Offset(0, _isPressed ? 2 : 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: _isPressed ? 0.1 : 0.16),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(LiquidGlassRefs.buttonEmbossInset),
      child: buttonFace,
    );

    if (!widget.useLiquidGlass) {
      return Tooltip(message: widget.tooltip, child: shell);
    }

    final liquidContent = DecoratedBox(
      decoration: const BoxDecoration(shape: BoxShape.rectangle),
      child: shell,
    );

    final child = isWindowsPlatform
        ? liquidContent
        : GlassGlow(
            glowColor: widget.isPrimary
                ? const Color.fromARGB(168, 255, 255, 255)
                : LiquidGlassRefs.buttonSecondaryGlowColor,
            glowRadius: widget.isPrimary
                ? LiquidGlassRefs.buttonPrimaryGlowRadius
                : LiquidGlassRefs.buttonSecondaryGlowRadius,
            child: liquidContent,
          );

    final glass = widget.grouped
        ? LiquidGlass.grouped(
            shape: const LiquidRoundedSuperellipse(
              borderRadius: LiquidGlassRefs.buttonEmbossRadius,
            ),
            child: child,
          )
        : LiquidGlass.withOwnLayer(
            settings: LiquidGlassRefs.isWindowsPlatform
                ? LiquidGlassRefs.loopTabsLayerSettingsWindows
                : LiquidGlassRefs.loopTabsLayerSettings,
            shape: const LiquidRoundedSuperellipse(
              borderRadius: LiquidGlassRefs.buttonEmbossRadius,
            ),
            child: child,
          );

    return Tooltip(
      message: widget.tooltip,
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

class _EmbossedButtonFace extends StatelessWidget {
  const _EmbossedButtonFace({
    required this.size,
    required this.isDisabled,
    required this.isPressed,
    required this.icon,
    required this.iconColor,
    required this.disabledIconColor,
    required this.backgroundColor,
    required this.disabledBackgroundColor,
    required this.buttonKey,
    required this.onPressed,
    required this.onHighlightChanged,
  });

  final double size;
  final bool isDisabled;
  final bool isPressed;
  final IconData icon;
  final Color iconColor;
  final Color disabledIconColor;
  final Color backgroundColor;
  final Color disabledBackgroundColor;
  final Key buttonKey;
  final VoidCallback onPressed;
  final ValueChanged<bool> onHighlightChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LiquidGlassRefs.buttonEmbossRadius),
        color: isDisabled ? disabledBackgroundColor : backgroundColor,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.white.withValues(alpha: isPressed ? 0.1 : 0.24),
            blurRadius: 6,
            offset: const Offset(-1, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isPressed ? 0.12 : 0.22),
            blurRadius: isPressed ? 4 : 8,
            offset: Offset(1, isPressed ? 2 : 5),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: buttonKey,
            onTap: isDisabled ? null : onPressed,
            onHighlightChanged: isDisabled ? null : onHighlightChanged,
            borderRadius:
                BorderRadius.circular(LiquidGlassRefs.buttonEmbossRadius),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll<Color>(
              Colors.transparent,
            ),
            child: Center(
              child: Icon(
                icon,
                size: size >= 58 ? 24 : 20,
                color: isDisabled ? disabledIconColor : iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
