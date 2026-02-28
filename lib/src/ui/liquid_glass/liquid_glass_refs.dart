import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Single source of truth for Liquid Glass tuning.
abstract final class LiquidGlassRefs {
  // Shared color tokens (synced with .pen fallback styling).
  static const Color editorBgBase = Color(0xFF2C2C2C);
  static const Color surfaceDeep = Color(0xFF121212);
  static const Color surfaceCard = Color.fromRGBO(147, 147, 147, 1);
  static const Color timelineSurface = Color(0xFF1B1C1C);
  static const Color accentBlue = Color(0xFF3D8BB8);
  static const Color accentOrange = Color.fromRGBO(245, 107, 61, 0.8);
  static const Color accentOrangeMuted = Color.fromRGBO(245, 107, 61, 0.6);
  static const Color textPrimary = Color(0xFFEAF7FF);
  static const Color textSecondary = Color(0xFFEAF7FF);
  static const Color outlineSoft = Color.fromRGBO(207, 207, 207, 0.2);

  // Transport bar layout.
  // Smaller => buttons are closer and blend easier.
  static const double transportButtonBlendSpacing = 4;
  static const double transportButtonSpacing = transportButtonBlendSpacing;
  static const double transportButtonSize = 42;
  static const double transportPrimaryButtonSize = 60;
  static const double transportPaddingHorizontal = 12;
  static const double transportPaddingVertical = 4;
  static const double transportCompactWidth = 420;

  // Transport layer and blending.
  static const LiquidGlassSettings transportLayerSettings = LiquidGlassSettings(
    thickness: 30,
    blur: 1,
    glassColor: Color.fromARGB(33, 142, 219, 214),
    lightIntensity: 0.8,
    ambientStrength: 0.0,
    saturation: 1.25,
  );
  // Windows-safe preset (keeps Liquid Glass while reducing GPU cost).
  static const LiquidGlassSettings transportLayerSettingsWindows =
      LiquidGlassSettings(
    thickness: 30,
    blur: 0.5,
    glassColor: Color.fromARGB(30, 142, 219, 214),
    lightIntensity: 0.62,
    ambientStrength: 0.02,
    saturation: 1.08,
  );
  static const double transportButtonsBlend = 20;

  // Loop mode tabs (normal loop / ping-pong).
  static const double loopTabsBlend = 20;
  static const double loopTabsHeight = 50;
  static const double loopTabsDesktopWidth = 220;
  static const double loopTabsMobileWidth = 190;
  static const double loopTabsOuterRadius = 25;
  static const double loopTabsInnerRadius = 21;
  static const double loopTabsInnerPadding = 4;
  static const double loopTabsDragVelocityThreshold = 120;
  static const LiquidGlassSettings loopTabsLayerSettings = LiquidGlassSettings(
    thickness: 30,
    blur: 1.5,
    glassColor: Color.fromARGB(31, 255, 255, 255),
    lightIntensity: 0.7,
    ambientStrength: 0.08,
    saturation: 1.2,
  );
  static const LiquidGlassSettings loopTabsLayerSettingsWindows =
      LiquidGlassSettings(
    thickness: 30,
    blur: 0.5,
    glassColor: Color.fromARGB(68, 224, 224, 224),
    lightIntensity: 0.62,
    ambientStrength: 0.05,
    saturation: 1.08,
  );

  // Export action buttons.
  static const double exportButtonHeight = 40;
  static const double exportButtonRadius = 999;
  static const double exportButtonHorizontalPadding = 14;
  static const double exportButtonGap = 8;
  static const LiquidGlassSettings exportButtonLayerSettings =
      LiquidGlassSettings(
    thickness: 30,
    blur: 1.2,
    glassColor: Color(0x1FFFFFFF),
    lightIntensity: 0.72,
    ambientStrength: 0.08,
    saturation: 1.15,
  );
  static const LiquidGlassSettings exportButtonLayerSettingsWindows =
      LiquidGlassSettings(
    thickness: 30,
    blur: 0.45,
    glassColor: Color.fromRGBO(255, 255, 255, 0.114),
    lightIntensity: 0.58,
    ambientStrength: 0.04,
    saturation: 1.06,
  );
  static const double exportButtonStretch = 0.28;
  static const double exportButtonInteractionScale = 1.03;
  static const double exportButtonStretchWindows = 0.12;
  static const double exportButtonInteractionScaleWindows = 1.015;

  // Range loop toggle.
  static const double rangeToggleTrackWidth = 62;
  static const double rangeToggleTrackHeight = 38;
  static const double rangeToggleThumbSize = 30;
  static const double rangeToggleBorderRadius = 999;
  static const double rangeToggleInnerPadding = 4;
  static const double rangeToggleBlend = 12;
  static const Color rangeToggleThumbOnColor = Color(0xFF6ECBF3);
  static const Color rangeToggleThumbOffColor = Colors.transparent;
  static const LiquidGlassSettings rangeToggleLayerSettings =
      LiquidGlassSettings(
    thickness: 30,
    blur: 1.0,
    glassColor: Color(0x1FFFFFFF),
    lightIntensity: 0.7,
    ambientStrength: 0.08,
    saturation: 1.1,
  );

  // Interactive button parameters.
  static const double buttonStretch = 0.45;
  static const double buttonInteractionScale = 1.3;
  static const double buttonStretchWindows = 0.12;
  static const double buttonInteractionScaleWindows = 1.02;
  static const double buttonPrimaryGlowRadius = 1.0;
  static const double buttonSecondaryGlowRadius = 0.8;
  static const Color buttonPrimaryGlowColor = Color.fromARGB(97, 255, 255, 255);
  static const Color buttonSecondaryGlowColor = Colors.white24;

  static bool get isWindowsPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  // Platform gate for liquid glass.
  static bool get supportsLiquidGlass {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows =>
        true,
      _ => false,
    };
  }
}
