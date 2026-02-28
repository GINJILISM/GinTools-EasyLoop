import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../liquid_glass/liquid_glass_refs.dart';

class LiquidGlassToggle extends StatelessWidget {
  const LiquidGlassToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final useLiquidGlass = LiquidGlassRefs.supportsLiquidGlass;

    if (!useLiquidGlass) {
      return Switch(
        value: value,
        activeThumbColor: LiquidGlassRefs.rangeToggleThumbOnColor,
        onChanged: onChanged,
      );
    }

    final enabled = onChanged != null;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Semantics(
        toggled: value,
        enabled: enabled,
        child: GestureDetector(
          onTap: enabled ? () => onChanged!.call(!value) : null,
          child: LiquidGlassLayer(
            settings: LiquidGlassRefs.rangeToggleLayerSettings,
            child: LiquidGlassBlendGroup(
              blend: LiquidGlassRefs.rangeToggleBlend,
              child: SizedBox(
                width: LiquidGlassRefs.rangeToggleTrackWidth,
                height: LiquidGlassRefs.rangeToggleTrackHeight,
                child: Stack(
                  children: <Widget>[
                    LiquidGlass.grouped(
                      shape: const LiquidRoundedSuperellipse(
                        borderRadius: LiquidGlassRefs.rangeToggleBorderRadius,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            LiquidGlassRefs.rangeToggleBorderRadius,
                          ),
                        ),
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment:
                          value ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          LiquidGlassRefs.rangeToggleInnerPadding,
                        ),
                        child: LiquidGlass.grouped(
                          shape: const LiquidOval(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: LiquidGlassRefs.rangeToggleThumbSize,
                            height: LiquidGlassRefs.rangeToggleThumbSize,
                            decoration: BoxDecoration(
                              color: value
                                  ? LiquidGlassRefs.rangeToggleThumbOnColor
                                  : LiquidGlassRefs.rangeToggleThumbOffColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
