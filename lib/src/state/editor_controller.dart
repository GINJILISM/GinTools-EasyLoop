import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/export_format.dart';
import '../models/gif_export_options.dart';
import '../models/loop_mode.dart';
import '../services/video_processor.dart';

class EditorController extends ChangeNotifier {
  EditorController({required this.videoProcessor});

  static const double minTrimLengthSeconds = 0.1;
  static const double defaultTrimEndOffsetSeconds = 1 / 30;
  static const double autoTrimAdjustEpsilonSeconds = 0.02;

  final VideoProcessor videoProcessor;

  Duration totalDuration = Duration.zero;
  double trimStartSeconds = 0;
  double trimEndSeconds = 0;
  double playheadSeconds = 0;
  double zoomLevel = 1.0;
  bool isAutoLoopEnabled = true;
  bool _hasUserEditedTrim = false;

  LoopMode loopMode = LoopMode.forward;
  ExportFormat exportFormat = ExportFormat.mp4;
  int loopCount = 4;
  GifQualityPreset gifQualityPreset = GifQualityPreset.medium;
  GifFpsPreset gifFpsPreset = GifFpsPreset.fps10;

  bool isExporting = false;
  bool isFrameExporting = false;
  double exportProgress = 0;
  String exportMessage = '';
  String? errorMessage;
  String? lastOutputPath;
  String? lastFrameOutputPath;

  Duration get trimStart =>
      Duration(milliseconds: (trimStartSeconds * 1000).round());
  Duration get trimEnd =>
      Duration(milliseconds: (trimEndSeconds * 1000).round());
  bool get hasUserEditedTrim => _hasUserEditedTrim;

  bool get canExport =>
      !isExporting &&
      !isFrameExporting &&
      totalDuration > Duration.zero &&
      trimEndSeconds - trimStartSeconds >= minTrimLengthSeconds;

  double pixelsPerSecondForViewport(double viewportWidth) {
    final totalSeconds = math.max(0.001, totalDuration.inMilliseconds / 1000);
    final fitPps = viewportWidth / totalSeconds;
    return fitPps * zoomLevel;
  }

  Future<void> loadDuration(String inputPath) async {
    try {
      final probed = await videoProcessor.probeDuration(inputPath);
      if (probed > Duration.zero) {
        setTotalDuration(probed);
      }
    } catch (_) {
      // プレイヤー側のduration取得にフォールバック。
    }
  }

  void setTotalDuration(Duration duration) {
    if (duration <= Duration.zero) {
      return;
    }

    final seconds = duration.inMilliseconds / 1000;
    totalDuration = duration;

    if (!_hasUserEditedTrim) {
      trimStartSeconds = 0;
      trimEndSeconds = _computeDefaultTrimEndSeconds(seconds);
    } else {
      trimStartSeconds = trimStartSeconds.clamp(0.0, seconds);
      trimEndSeconds = trimEndSeconds.clamp(0.0, seconds);
      if (trimEndSeconds - trimStartSeconds < minTrimLengthSeconds) {
        trimEndSeconds = (trimStartSeconds + minTrimLengthSeconds).clamp(
          0.0,
          seconds,
        );
      }
    }

    playheadSeconds = playheadSeconds
        .clamp(trimStartSeconds, trimEndSeconds)
        .toDouble();
    notifyListeners();
  }

  double _computeDefaultTrimEndSeconds(double totalSeconds) {
    if (totalSeconds <= minTrimLengthSeconds) {
      return totalSeconds;
    }

    final defaultEnd = totalSeconds - defaultTrimEndOffsetSeconds;
    return defaultEnd.clamp(minTrimLengthSeconds, totalSeconds).toDouble();
  }

  void resetTrimToFullRange() {
    if (totalDuration <= Duration.zero) {
      return;
    }

    trimStartSeconds = 0;
    trimEndSeconds = totalDuration.inMilliseconds / 1000;
    playheadSeconds = 0;
    _hasUserEditedTrim = false;
    notifyListeners();
  }

  void setAutoDetectedTrimEnd(double endSeconds) {
    if (totalDuration <= Duration.zero || _hasUserEditedTrim) {
      return;
    }

    final maxSeconds = totalDuration.inMilliseconds / 1000;
    final nextEnd = endSeconds.clamp(minTrimLengthSeconds, maxSeconds);
    if ((trimEndSeconds - nextEnd).abs() < autoTrimAdjustEpsilonSeconds) {
      return;
    }

    trimStartSeconds = 0;
    trimEndSeconds = nextEnd.toDouble();
    playheadSeconds = playheadSeconds
        .clamp(trimStartSeconds, trimEndSeconds)
        .toDouble();
    notifyListeners();
  }

  void setTrimRange({
    required double startSeconds,
    required double endSeconds,
  }) {
    if (totalDuration <= Duration.zero) {
      return;
    }

    final maxSeconds = totalDuration.inMilliseconds / 1000;
    var nextStart = startSeconds.clamp(0.0, maxSeconds);
    var nextEnd = endSeconds.clamp(0.0, maxSeconds);

    if (nextEnd - nextStart < minTrimLengthSeconds) {
      if (endSeconds >= trimEndSeconds) {
        nextEnd = (nextStart + minTrimLengthSeconds).clamp(0.0, maxSeconds);
      } else {
        nextStart = (nextEnd - minTrimLengthSeconds).clamp(0.0, maxSeconds);
      }
    }

    trimStartSeconds = nextStart;
    trimEndSeconds = nextEnd;
    _hasUserEditedTrim = true;
    playheadSeconds = playheadSeconds
        .clamp(trimStartSeconds, trimEndSeconds)
        .toDouble();
    notifyListeners();
  }

  void seekTo(double seconds) {
    playheadSeconds = seconds
        .clamp(0.0, totalDuration.inMilliseconds / 1000)
        .toDouble();
    notifyListeners();
  }

  void setPlayheadFromScrub(double seconds) {
    playheadSeconds = seconds
        .clamp(0.0, totalDuration.inMilliseconds / 1000)
        .toDouble();
    notifyListeners();
  }

  void updatePlayhead(double seconds) {
    final next = seconds
        .clamp(0.0, totalDuration.inMilliseconds / 1000)
        .toDouble();
    if ((next - playheadSeconds).abs() < 0.10) {
      return;
    }
    playheadSeconds = next;
    notifyListeners();
  }

  void setZoomLevel(double value) {
    zoomLevel = value.clamp(0.5, 5.0);
    notifyListeners();
  }

  void setAutoLoopEnabled(bool value) {
    isAutoLoopEnabled = value;
    notifyListeners();
  }

  void setLoopMode(LoopMode mode) {
    loopMode = mode;
    notifyListeners();
  }

  void setExportFormat(ExportFormat format) {
    exportFormat = format;
    notifyListeners();
  }

  void setGifQualityPreset(GifQualityPreset preset) {
    gifQualityPreset = preset;
    notifyListeners();
  }

  void setGifFpsPreset(GifFpsPreset preset) {
    gifFpsPreset = preset;
    notifyListeners();
  }

  void setLoopCount(int count) {
    loopCount = count.clamp(1, 20);
    notifyListeners();
  }

  Future<bool> export({
    required String inputPath,
    required String outputPath,
  }) async {
    if (!canExport) {
      errorMessage = '書き出し可能な状態ではありません。';
      notifyListeners();
      return false;
    }

    isExporting = true;
    exportProgress = 0;
    exportMessage = '書き出しを開始しています...';
    errorMessage = null;
    lastOutputPath = null;
    notifyListeners();

    try {
      final request = ExportRequest(
        inputPath: inputPath,
        outputPath: outputPath,
        trimStart: trimStart,
        trimEnd: trimEnd,
        loopMode: loopMode,
        loopCount: loopCount,
        format: exportFormat,
        gifQualityPreset: gifQualityPreset,
        gifFps: gifFpsPreset.value,
        muteAudio: true,
      );

      final generatedPath = await videoProcessor.export(
        request,
        onProgress: (progress, message) {
          exportProgress = progress.clamp(0.0, 1.0);
          exportMessage = message;
          notifyListeners();
        },
      );

      lastOutputPath = generatedPath;
      exportProgress = 1;
      exportMessage = '書き出しが完了しました。';
      notifyListeners();
      return true;
    } on ExportException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (error) {
      errorMessage = '書き出し中に予期しないエラーが発生しました: $error';
      notifyListeners();
      return false;
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<bool> exportCurrentFrameJpeg({
    required String inputPath,
    required double positionSeconds,
    String? outputPath,
  }) async {
    if (isExporting || isFrameExporting || totalDuration <= Duration.zero) {
      errorMessage = '現在の状態ではフレーム書き出しできません。';
      notifyListeners();
      return false;
    }

    isFrameExporting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final targetOutputPath = outputPath ?? await _defaultFrameOutputPath();
      final clampedPosition = positionSeconds
          .clamp(0.0, totalDuration.inMilliseconds / 1000)
          .toDouble();

      final generatedPath = await videoProcessor.exportFrameJpeg(
        FrameExportRequest(
          inputPath: inputPath,
          outputPath: targetOutputPath,
          position: Duration(milliseconds: (clampedPosition * 1000).round()),
          qualityPreset: FrameExportQualityPreset.max,
        ),
      );

      lastFrameOutputPath = generatedPath;
      notifyListeners();
      return true;
    } on ExportException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (error) {
      errorMessage = 'フレーム書き出し中に予期しないエラーが発生しました: $error';
      notifyListeners();
      return false;
    } finally {
      isFrameExporting = false;
      notifyListeners();
    }
  }

  Future<String> _defaultFrameOutputPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp('[:.]'),
      '-',
    );
    return p.join(docsDir.path, 'frame_$timestamp.jpg');
  }
}
