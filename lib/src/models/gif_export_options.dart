import '../ui/app_strings.dart';

enum GifQualityPreset {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case GifQualityPreset.low:
        return AppStrings.gifQualityLow;
      case GifQualityPreset.medium:
        return AppStrings.gifQualityMedium;
      case GifQualityPreset.high:
        return AppStrings.gifQualityHigh;
    }
  }
}

enum GifFpsPreset {
  fps5(5),
  fps10(10),
  fps24(24);

  const GifFpsPreset(this.value);

  final int value;

  String get label => AppStrings.gifFpsLabel(value);
}
