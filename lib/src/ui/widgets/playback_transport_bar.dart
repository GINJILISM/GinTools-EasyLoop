import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../liquid_glass/liquid_glass_refs.dart';
import 'interactive_liquid_glass_icon_button.dart';
import '../app_strings.dart';

class PlaybackTransportBar extends StatelessWidget {
  const PlaybackTransportBar({
    super.key,
    required this.isPlaying,
    required this.isDisabled,
    required this.onSetStart,
    required this.onJumpStart,
    required this.onStepPrev,
    required this.onPlayPause,
    required this.onStepNext,
    required this.onJumpEnd,
    required this.onSetEnd,
  });

  final bool isPlaying;
  final bool isDisabled;

  final VoidCallback onSetStart;
  final VoidCallback onJumpStart;
  final VoidCallback onStepPrev;
  final VoidCallback onPlayPause;
  final VoidCallback onStepNext;
  final VoidCallback onJumpEnd;
  final VoidCallback onSetEnd;

  @override
  Widget build(BuildContext context) {
    final useLiquidGlass = LiquidGlassRefs.supportsLiquidGlass;
    final layerSettings = LiquidGlassRefs.isWindowsPlatform
        ? LiquidGlassRefs.transportLayerSettingsWindows
        : LiquidGlassRefs.transportLayerSettings;

    final alignedButtonHeight = LiquidGlassRefs.transportPrimaryButtonSize;

    final buttons = <Widget>[
      _centerAlignedButton(
        height: alignedButtonHeight,
        child: InteractiveLiquidGlassIconButton(
        buttonKey: const Key('transport-set-start'),
        icon: Icons.first_page_rounded,
        tooltip: AppStrings.setCurrentAsStart,
        isDisabled: isDisabled,
        onPressed: onSetStart,
        useLiquidGlass: useLiquidGlass,
        grouped: useLiquidGlass,
        backgroundColor: LiquidGlassRefs.transportBoundaryButtonColor,
        foregroundColor: LiquidGlassRefs.textPrimary,
      ),
      ),
      _centerAlignedButton(
        height: alignedButtonHeight,
        child: InteractiveLiquidGlassIconButton(
        buttonKey: const Key('transport-trim-start'),
        icon: Icons.skip_previous_rounded,
        tooltip: AppStrings.jumpToStart,
        isDisabled: isDisabled,
        onPressed: onJumpStart,
        useLiquidGlass: useLiquidGlass,
        grouped: useLiquidGlass,
        backgroundColor: LiquidGlassRefs.transportSecondaryButtonColor,
        foregroundColor: LiquidGlassRefs.textPrimary,
      ),
      ),
      _centerAlignedButton(
        height: alignedButtonHeight,
        child: InteractiveLiquidGlassIconButton(
        buttonKey: const Key('transport-frame-prev'),
        icon: Icons.fast_rewind_rounded,
        tooltip: AppStrings.stepBackOneFrame,
        isDisabled: isDisabled,
        onPressed: onStepPrev,
        useLiquidGlass: useLiquidGlass,
        grouped: useLiquidGlass,
        backgroundColor: LiquidGlassRefs.transportSecondaryButtonColor,
        foregroundColor: LiquidGlassRefs.textPrimary,
      ),
      ),
      _centerAlignedButton(
        height: alignedButtonHeight,
        child: InteractiveLiquidGlassIconButton(
        buttonKey: const Key('transport-play-pause'),
        icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        tooltip: isPlaying ? AppStrings.pause : AppStrings.play,
        isDisabled: isDisabled,
        onPressed: onPlayPause,
        useLiquidGlass: useLiquidGlass,
        grouped: useLiquidGlass,
        isPrimary: true,
        backgroundColor: LiquidGlassRefs.accentOrange,
        foregroundColor: Colors.white,
      ),
      ),
      _centerAlignedButton(
        height: alignedButtonHeight,
        child: InteractiveLiquidGlassIconButton(
        buttonKey: const Key('transport-frame-next'),
        icon: Icons.fast_forward_rounded,
        tooltip: AppStrings.stepForwardOneFrame,
        isDisabled: isDisabled,
        onPressed: onStepNext,
        useLiquidGlass: useLiquidGlass,
        grouped: useLiquidGlass,
        backgroundColor: LiquidGlassRefs.transportSecondaryButtonColor,
        foregroundColor: LiquidGlassRefs.textPrimary,
      ),
      ),
      _centerAlignedButton(
        height: alignedButtonHeight,
        child: InteractiveLiquidGlassIconButton(
        buttonKey: const Key('transport-trim-end'),
        icon: Icons.skip_next_rounded,
        tooltip: AppStrings.jumpToEnd,
        isDisabled: isDisabled,
        onPressed: onJumpEnd,
        useLiquidGlass: useLiquidGlass,
        grouped: useLiquidGlass,
        backgroundColor: LiquidGlassRefs.transportSecondaryButtonColor,
        foregroundColor: LiquidGlassRefs.textPrimary,
      ),
      ),
      _centerAlignedButton(
        height: alignedButtonHeight,
        child: InteractiveLiquidGlassIconButton(
        buttonKey: const Key('transport-set-end'),
        icon: Icons.last_page_rounded,
        tooltip: AppStrings.setCurrentAsEnd,
        isDisabled: isDisabled,
        onPressed: onSetEnd,
        useLiquidGlass: useLiquidGlass,
        grouped: useLiquidGlass,
        backgroundColor: LiquidGlassRefs.transportBoundaryButtonColor,
        foregroundColor: LiquidGlassRefs.textPrimary,
      ),
      ),
    ];

    final buttonsCore = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _withSpacing(
          buttons,
          spacing: LiquidGlassRefs.transportButtonBlendSpacing,
        ),
      ),
    );

    final groupedButtons = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LiquidGlassRefs.transportPaddingHorizontal,
        vertical: LiquidGlassRefs.transportPaddingVertical,
      ),
      child: buttonsCore,
    );

    if (!useLiquidGlass) {
      return KeyedSubtree(
        key: const Key('preview-transport-overlay'),
        child: groupedButtons,
      );
    }

    return LiquidGlassLayer(
      key: const Key('preview-transport-overlay'),
      settings: layerSettings,
      child: LiquidGlassBlendGroup(
        blend: LiquidGlassRefs.transportButtonsBlend,
        child: groupedButtons,
      ),
    );
  }

  Widget _centerAlignedButton({
    required double height,
    required Widget child,
  }) {
    return SizedBox(
      height: height,
      child: Center(child: child),
    );
  }

  List<Widget> _withSpacing(
    List<Widget> widgets, {
    required double spacing,
  }) {
    if (widgets.isEmpty) return widgets;
    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) {
        result.add(SizedBox(width: spacing));
      }
      result.add(widgets[i]);
    }
    return result;
  }
}
