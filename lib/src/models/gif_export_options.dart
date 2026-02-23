enum GifQualityPreset {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case GifQualityPreset.low:
        return '低 (約200px)';
      case GifQualityPreset.medium:
        return '中 (50%解像度)';
      case GifQualityPreset.high:
        return '高 (100%解像度)';
    }
  }
}

enum GifFpsPreset {
  fps5(5),
  fps10(10),
  fps24(24);

  const GifFpsPreset(this.value);

  final int value;

  String get label => '$value FPS';
}
