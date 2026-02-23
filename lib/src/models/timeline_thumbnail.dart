class TimelineThumbnail {
  const TimelineThumbnail({
    required this.path,
    required this.startSecond,
    required this.endSecond,
  });

  final String path;
  final double startSecond;
  final double endSecond;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'startSecond': startSecond,
    'endSecond': endSecond,
  };

  static TimelineThumbnail fromJson(Map<String, dynamic> json) {
    return TimelineThumbnail(
      path: json['path'] as String,
      startSecond: (json['startSecond'] as num).toDouble(),
      endSecond: (json['endSecond'] as num).toDouble(),
    );
  }
}
