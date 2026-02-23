import '../models/export_format.dart';
import '../models/loop_mode.dart';

typedef ProgressCallback = void Function(double progress, String message);

class ExportRequest {
  ExportRequest({
    required this.inputPath,
    required this.outputPath,
    required this.trimStart,
    required this.trimEnd,
    required this.loopMode,
    required this.loopCount,
    required this.format,
    this.muteAudio = true,
  });

  final String inputPath;
  final String outputPath;
  final Duration trimStart;
  final Duration trimEnd;
  final LoopMode loopMode;
  final int loopCount;
  final ExportFormat format;
  final bool muteAudio;
}

abstract class VideoProcessor {
  Future<Duration> probeDuration(String inputPath);

  Future<String> export(
    ExportRequest request, {
    required ProgressCallback onProgress,
  });
}

class ExportException implements Exception {
  ExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
