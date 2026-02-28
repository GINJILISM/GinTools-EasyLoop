import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../models/loop_mode.dart';
import '../liquid_glass/liquid_glass_refs.dart';

enum _LoopTabsSelection {
  off,
  forward,
  pingPong,
}

class LoopModeGlassTabs extends StatelessWidget {
  const LoopModeGlassTabs({
    super.key,
    required this.loopMode,
    required this.isAutoLoopEnabled,
    required this.onLoopModeChanged,
    required this.onAutoLoopChanged,
    required this.width,
    this.enabled = true,
  });

  final LoopMode loopMode;
  final bool isAutoLoopEnabled;
  final ValueChanged<LoopMode> onLoopModeChanged;
  final ValueChanged<bool> onAutoLoopChanged;
  final double width;
  final bool enabled;

  _LoopTabsSelection get _selection {
    if (!isAutoLoopEnabled) return _LoopTabsSelection.off;
    return loopMode == LoopMode.pingPong
        ? _LoopTabsSelection.pingPong
        : _LoopTabsSelection.forward;
  }

  @override
  Widget build(BuildContext context) {
    final useLiquidGlass = LiquidGlassRefs.supportsLiquidGlass;
    final layerSettings = LiquidGlassRefs.isWindowsPlatform
        ? LiquidGlassRefs.loopTabsLayerSettingsWindows
        : LiquidGlassRefs.loopTabsLayerSettings;
    final selected = _selection;
    final activeAlignment = _alignmentFor(selected);

    final tabBody = SizedBox(
      width: width,
      height: LiquidGlassRefs.loopTabsHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth =
              constraints.maxWidth / _LoopTabsSelection.values.length;
          return GestureDetector(
            onHorizontalDragEnd: enabled ? _handleHorizontalDrag : null,
            child: Stack(
              children: <Widget>[
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: activeAlignment,
                  child: Padding(
                    padding: const EdgeInsets.all(
                      LiquidGlassRefs.loopTabsInnerPadding,
                    ),
                    child: SizedBox(
                      width: segmentWidth -
                          (LiquidGlassRefs.loopTabsInnerPadding * 2),
                      height: LiquidGlassRefs.loopTabsHeight -
                          (LiquidGlassRefs.loopTabsInnerPadding * 2),
                      child: _buildActiveThumb(useLiquidGlass: useLiquidGlass),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    _buildTab(
                      selection: _LoopTabsSelection.off,
                      tooltip: 'ループオフ',
                    ),
                    _buildTab(
                      selection: _LoopTabsSelection.forward,
                      tooltip: '通常ループ',
                    ),
                    _buildTab(
                      selection: _LoopTabsSelection.pingPong,
                      tooltip: 'ピンポンループ',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!useLiquidGlass) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: LiquidGlassRefs.surfaceDeep.withValues(alpha: 0.16),
          borderRadius:
              BorderRadius.circular(LiquidGlassRefs.loopTabsOuterRadius),
          border: Border.all(color: LiquidGlassRefs.outlineSoft),
        ),
        child: tabBody,
      );
    }

    return LiquidGlassLayer(
      settings: layerSettings,
      child: LiquidGlassBlendGroup(
        blend: LiquidGlassRefs.loopTabsBlend,
        child: LiquidGlass.grouped(
          shape: const LiquidRoundedSuperellipse(
            borderRadius: LiquidGlassRefs.loopTabsOuterRadius,
          ),
          child: tabBody,
        ),
      ),
    );
  }

  Widget _buildActiveThumb({required bool useLiquidGlass}) {
    if (!useLiquidGlass) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF3D8BB8).withValues(alpha: 0.9),
          borderRadius:
              BorderRadius.circular(LiquidGlassRefs.loopTabsInnerRadius),
        ),
      );
    }

    return LiquidGlass.grouped(
      shape: const LiquidRoundedSuperellipse(
        borderRadius: LiquidGlassRefs.loopTabsInnerRadius,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LiquidGlassRefs.accentBlue,
          borderRadius:
              BorderRadius.circular(LiquidGlassRefs.loopTabsInnerRadius),
        ),
      ),
    );
  }

  Widget _buildTab({
    required _LoopTabsSelection selection,
    required String tooltip,
  }) {
    final selected = _selection == selection;
    final iconColor =
        selected ? LiquidGlassRefs.textPrimary : const Color(0xFF3D8BB8);

    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: enabled ? () => _applySelection(selection) : null,
          borderRadius:
              BorderRadius.circular(LiquidGlassRefs.loopTabsOuterRadius),
          child: Center(
            child: _buildModeIcon(
              selection: selection,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeIcon({
    required _LoopTabsSelection selection,
    required Color color,
  }) {
    const baseSize = 20.0;
    const overlaySize = 12.0;

    final base = Icon(Icons.loop_rounded, size: baseSize, color: color);
    switch (selection) {
      case _LoopTabsSelection.off:
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            base,
            Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 2.4,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        );
      case _LoopTabsSelection.forward:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.arrow_right_alt_rounded,
              size: overlaySize,
              color: color,
            ),
            const SizedBox(height: 1),
            base,
          ],
        );
      case _LoopTabsSelection.pingPong:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.compare_arrows_rounded,
              size: overlaySize,
              color: color,
            ),
            const SizedBox(height: 1),
            base,
          ],
        );
    }
  }

  Alignment _alignmentFor(_LoopTabsSelection selection) {
    return switch (selection) {
      _LoopTabsSelection.off => Alignment.centerLeft,
      _LoopTabsSelection.forward => Alignment.center,
      _LoopTabsSelection.pingPong => Alignment.centerRight,
    };
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < LiquidGlassRefs.loopTabsDragVelocityThreshold) {
      return;
    }
    final currentIndex = _selection.index;
    final step = velocity < 0 ? 1 : -1;
    final nextIndex =
        (currentIndex + step).clamp(0, _LoopTabsSelection.values.length - 1);
    if (nextIndex == currentIndex) return;
    _applySelection(_LoopTabsSelection.values[nextIndex]);
  }

  void _applySelection(_LoopTabsSelection next) {
    switch (next) {
      case _LoopTabsSelection.off:
        if (isAutoLoopEnabled) {
          onAutoLoopChanged(false);
        }
        return;
      case _LoopTabsSelection.forward:
        if (!isAutoLoopEnabled) {
          onAutoLoopChanged(true);
        }
        if (loopMode != LoopMode.forward) {
          onLoopModeChanged(LoopMode.forward);
        }
        return;
      case _LoopTabsSelection.pingPong:
        if (!isAutoLoopEnabled) {
          onAutoLoopChanged(true);
        }
        if (loopMode != LoopMode.pingPong) {
          onLoopModeChanged(LoopMode.pingPong);
        }
        return;
    }
  }
}
