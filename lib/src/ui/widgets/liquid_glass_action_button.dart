import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../design/typography/app_font_roles.dart';
import '../liquid_glass/liquid_glass_refs.dart';

class LiquidGlassActionButton extends StatefulWidget {
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
  State<LiquidGlassActionButton> createState() =>
      _LiquidGlassActionButtonState();
}

class _LiquidGlassActionButtonState extends State<LiquidGlassActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final useLiquidGlass = LiquidGlassRefs.supportsLiquidGlass;
    final isWindowsPlatform = LiquidGlassRefs.isWindowsPlatform;
    final enabled = widget.onPressed != null;
    final colorScheme = Theme.of(context).colorScheme;
    final actionLabelBaseStyle = AppFontRoles.actionButtonLabel(
      Theme.of(context).textTheme.labelLarge,
    );

    final resolvedForegroundColor = widget.foregroundColor ??
        (widget.primary ? colorScheme.primary : colorScheme.onSurface);

    final fg = resolvedForegroundColor;
    final disabledFg = colorScheme.onSurface.withValues(alpha: 0.45);
    final resolvedFillColor = widget.fillColor ??
        (widget.primary
            ? colorScheme.primaryContainer.withValues(alpha: 0.92)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72));
    final pressedShadowOffset =
        isWindowsPlatform ? const Offset(0, 2) : const Offset(0, 3);
    final releasedShadowOffset =
        isWindowsPlatform ? const Offset(0, 6) : const Offset(0, 9);
    final pressDepth = isWindowsPlatform
        ? LiquidGlassRefs.exportButtonPressDepthWindows
        : LiquidGlassRefs.exportButtonPressDepth;

    final buttonFace = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(
        0,
        enabled ? (_isPressed ? pressDepth : 0) : 0,
        0,
      ),
      child: _EmbossedActionButtonFace(
        isEnabled: enabled,
        isPressed: _isPressed,
        height: LiquidGlassRefs.exportButtonHeight,
        icon: widget.icon,
        label: widget.label,
        iconColor: fg,
        disabledIconColor: disabledFg,
        labelStyle: actionLabelBaseStyle,
        fillColor: resolvedFillColor,
        disabledFillColor:
            resolvedFillColor.withValues(alpha: resolvedFillColor.a * 0.58),
        borderColor: widget.borderColor,
        onPressed: widget.onPressed,
        onHighlightChanged: (pressed) {
          if (!enabled || pressed == _isPressed) {
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
        borderRadius: BorderRadius.circular(LiquidGlassRefs.exportButtonRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: _isPressed ? 0.16 : 0.26),
            Colors.black.withValues(alpha: _isPressed ? 0.12 : 0.2),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isPressed ? 0.08 : 0.14),
            blurRadius: _isPressed ? 4 : 9,
            offset: _isPressed ? pressedShadowOffset : releasedShadowOffset,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: _isPressed ? 0.08 : 0.14),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(LiquidGlassRefs.exportButtonEmbossInset),
      child: buttonFace,
    );

    if (!useLiquidGlass) {
      return Opacity(opacity: enabled ? 1 : 0.55, child: shell);
    }

    final child = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LiquidGlassRefs.exportButtonRadius),
      ),
      child: shell,
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
              glowColor: widget.primary ? Colors.white30 : Colors.white24,
              glowRadius: widget.primary ? 0.9 : 0.7,
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

class _EmbossedActionButtonFace extends StatelessWidget {
  const _EmbossedActionButtonFace({
    required this.isEnabled,
    required this.isPressed,
    required this.height,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.disabledIconColor,
    required this.labelStyle,
    required this.fillColor,
    required this.disabledFillColor,
    required this.borderColor,
    required this.onPressed,
    required this.onHighlightChanged,
  });

  final bool isEnabled;
  final bool isPressed;
  final double height;
  final Widget icon;
  final Widget label;
  final Color iconColor;
  final Color disabledIconColor;
  final TextStyle? labelStyle;
  final Color fillColor;
  final Color disabledFillColor;
  final Color? borderColor;
  final VoidCallback? onPressed;
  final ValueChanged<bool> onHighlightChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveForeground = isEnabled ? iconColor : disabledIconColor;
    final effectiveFill = isEnabled ? fillColor : disabledFillColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(LiquidGlassRefs.exportButtonRadius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.white.withValues(alpha: isPressed ? 0.08 : 0.18),
            blurRadius: 6,
            offset: const Offset(-1, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isPressed ? 0.1 : 0.2),
            blurRadius: isPressed ? 4 : 8,
            offset: Offset(1, isPressed ? 2 : 5),
          ),
        ],
      ),
      child: SizedBox(
        height: height,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            onHighlightChanged: isEnabled ? onHighlightChanged : null,
            borderRadius:
                BorderRadius.circular(LiquidGlassRefs.exportButtonRadius),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll<Color>(
              Colors.transparent,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LiquidGlassRefs.exportButtonHorizontalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconTheme(
                    data: IconThemeData(color: effectiveForeground),
                    child: icon,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: DefaultTextStyle(
                      style: labelStyle?.copyWith(
                            color: effectiveForeground,
                            fontWeight: FontWeight.w700,
                          ) ??
                          TextStyle(
                            color: effectiveForeground,
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: label,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
