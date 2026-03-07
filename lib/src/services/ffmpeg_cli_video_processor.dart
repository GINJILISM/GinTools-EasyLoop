import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/export_format.dart';
import '../models/gif_export_options.dart';
import '../models/loop_mode.dart';
import '../ui/app_strings.dart';
import 'video_processor.dart';

class FfmpegCliVideoProcessor implements VideoProcessor {
  FfmpegCliVideoProcessor({
    this.ffmpegExecutable = 'ffmpeg',
    this.ffprobeExecutable = 'ffprobe',
  });

  final String ffmpegExecutable;
  final String ffprobeExecutable;
  bool _toolChecked = false;

  bool get _useEmbeddedFfmpegKit {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  Future<Duration> probeDuration(String inputPath) async {
    await _ensureToolsAvailable();
    final resolvedInputPath = _resolveInputPath(inputPath);

    if (_useEmbeddedFfmpegKit) {
      final session = await FFprobeKit.getMediaInformation(resolvedInputPath);
      final mediaInfo = await session.getMediaInformation();
      final raw = mediaInfo?.getDuration();
      final seconds = double.tryParse(raw ?? '');
      if (seconds == null || seconds <= 0) {
        throw ExportException(AppStrings.failedToGetVideoDuration);
      }
      return Duration(milliseconds: (seconds * 1000).round());
    }

    final result = await Process.run(ffprobeExecutable, <String>[
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      resolvedInputPath,
    ], runInShell: true);

    if (result.exitCode != 0) {
      throw ExportException(AppStrings.failedToParseVideoDuration);
    }

    final raw = (result.stdout as String).trim();
    final seconds = double.tryParse(raw);
    if (seconds == null || seconds <= 0) {
      throw ExportException(AppStrings.failedToGetVideoDuration);
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  Future<String> export(
    ExportRequest request, {
    required ProgressCallback onProgress,
  }) async {
    await _ensureToolsAvailable();

    final clipDuration = request.trimEnd - request.trimStart;
    if (clipDuration <= Duration.zero) {
      throw ExportException(AppStrings.invalidTrimRange);
    }
    if (request.loopCount < 1) {
      throw ExportException(AppStrings.invalidLoopCount);
    }

    final tempRoot = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempRoot.path,
        'loop_export_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await workDir.create(recursive: true);
    await Directory(p.dirname(request.outputPath)).create(recursive: true);
    final processingInputPath = await _prepareInputForProcessing(
      request.inputPath,
      workDir,
    );

    final forwardClip = p.join(workDir.path, 'forward.mp4');
    final reverseClip = p.join(workDir.path, 'reverse.mp4');
    final concatList = p.join(workDir.path, 'concat.txt');
    final cycleClip = p.join(workDir.path, 'cycle.mp4');
    final palettePath = p.join(workDir.path, 'palette.png');

    try {
      onProgress(0.02, AppStrings.trimming);
      await _runFfmpeg(
        <String>[
          '-y',
          '-i',
          processingInputPath,
          '-ss',
          _formatDurationForFfmpeg(request.trimStart),
          '-to',
          _formatDurationForFfmpeg(request.trimEnd),
          '-an',
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-crf',
          '18',
          '-pix_fmt',
          'yuv420p',
          forwardClip,
        ],
        expectedDurationSeconds: clipDuration.inMilliseconds / 1000,
        onStepProgress: (progress) {
          onProgress(_normalizeProgress(0.02, 0.30, progress), AppStrings.trimming);
        },
      );

      if (request.format == ExportFormat.gif) {
        final cycleInput = await _prepareGifCycle(
          request: request,
          forwardClip: forwardClip,
          reverseClip: reverseClip,
          concatList: concatList,
          cycleClip: cycleClip,
          clipDuration: clipDuration,
          onProgress: onProgress,
        );

        onProgress(0.65, AppStrings.generatingGifPalette);
        await _runFfmpeg(
          buildGifPaletteArgs(
            inputPath: cycleInput,
            palettePath: palettePath,
            fps: request.gifFps,
            qualityPreset: request.gifQualityPreset,
          ),
          expectedDurationSeconds: clipDuration.inMilliseconds / 1000,
          onStepProgress: (progress) {
            onProgress(
              _normalizeProgress(0.65, 0.12, progress),
              AppStrings.generatingGifPalette,
            );
          },
        );

        onProgress(0.78, AppStrings.gifEncoding);
        await _runFfmpeg(
          buildGifRenderArgs(
            inputPath: cycleInput,
            palettePath: palettePath,
            outputPath: request.outputPath,
            fps: request.gifFps,
            qualityPreset: request.gifQualityPreset,
          ),
          expectedDurationSeconds: clipDuration.inMilliseconds / 1000,
          onStepProgress: (progress) {
            onProgress(
              _normalizeProgress(0.78, 0.21, progress),
              AppStrings.gifEncoding,
            );
          },
        );

        onProgress(1, AppStrings.exportDone);
        return request.outputPath;
      }

      if (request.loopMode == LoopMode.forward) {
        final listContent = List<String>.generate(
          request.loopCount,
          (_) => _concatFileLine(forwardClip),
        ).join('\n');
        await File(concatList).writeAsString(listContent);

        onProgress(0.38, AppStrings.concatenating);
        await _runFfmpeg(
          <String>[
            '-y',
            '-f',
            'concat',
            '-safe',
            '0',
            '-i',
            concatList,
            '-an',
            '-c:v',
            'libx264',
            '-preset',
            'veryfast',
            '-crf',
            '18',
            '-movflags',
            '+faststart',
            '-pix_fmt',
            'yuv420p',
            request.outputPath,
          ],
          expectedDurationSeconds:
              (clipDuration.inMilliseconds / 1000) * request.loopCount,
          onStepProgress: (progress) {
            onProgress(_normalizeProgress(0.38, 0.61, progress), AppStrings.concatenating);
          },
        );
      } else {
        onProgress(0.38, AppStrings.generatingReverseClip);
        await _buildReverseClip(
          forwardClip: forwardClip,
          reverseClip: reverseClip,
          clipDuration: clipDuration,
          onProgress: (progress, message) {
            onProgress(_normalizeProgress(0.38, 0.20, progress), message);
          },
        );

        final pingPongContent = List<String>.generate(
          request.loopCount,
          (_) =>
              '${_concatFileLine(forwardClip)}\n${_concatFileLine(reverseClip)}',
        ).join('\n');
        await File(concatList).writeAsString(pingPongContent);

        onProgress(0.60, AppStrings.pingPongConcatenating);
        await _runFfmpeg(
          <String>[
            '-y',
            '-f',
            'concat',
            '-safe',
            '0',
            '-i',
            concatList,
            '-an',
            '-c:v',
            'libx264',
            '-preset',
            'veryfast',
            '-crf',
            '18',
            '-movflags',
            '+faststart',
            '-pix_fmt',
            'yuv420p',
            request.outputPath,
          ],
          expectedDurationSeconds:
              (clipDuration.inMilliseconds / 1000) * request.loopCount * 2,
          onStepProgress: (progress) {
            onProgress(_normalizeProgress(0.60, 0.39, progress), AppStrings.pingPongConcatenating);
          },
        );
      }

      onProgress(1, AppStrings.exportDone);
      return request.outputPath;
    } on ProcessException {
      throw ExportException(AppStrings.ffmpegNotFoundInPath);
    } finally {
      if (workDir.existsSync()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  @override
  Future<String> exportFrameJpeg(FrameExportRequest request) async {
    await _ensureToolsAvailable();
    await Directory(p.dirname(request.outputPath)).create(recursive: true);

    final tempRoot = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempRoot.path,
        'frame_export_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await workDir.create(recursive: true);

    final processingInputPath = await _prepareInputForProcessing(
      request.inputPath,
      workDir,
    );

    try {
      await _runFfmpeg(
        buildFrameJpegArgs(
          request: FrameExportRequest(
            inputPath: processingInputPath,
            outputPath: request.outputPath,
            position: request.position,
            qualityPreset: request.qualityPreset,
          ),
        ),
        expectedDurationSeconds: 1,
        onStepProgress: (_) {},
      );
    } finally {
      if (workDir.existsSync()) {
        await workDir.delete(recursive: true);
      }
    }

    return request.outputPath;
  }

  Future<String> _prepareInputForProcessing(
    String rawInputPath,
    Directory workDir,
  ) async {
    final resolvedPath = _resolveInputPath(rawInputPath);
    final inputFile = File(resolvedPath);
    if (!await inputFile.exists()) {
      throw ExportException(AppStrings.inputVideoNotFound(resolvedPath));
    }

    if (!_useEmbeddedFfmpegKit) {
      return resolvedPath;
    }

    final extension = p.extension(resolvedPath).trim();
    final stagedPath = p.join(
      workDir.path,
      'input${extension.isEmpty ? '' : extension}',
    );

    if (p.equals(resolvedPath, stagedPath)) {
      return resolvedPath;
    }

    try {
      await inputFile.copy(stagedPath);
      return stagedPath;
    } on FileSystemException catch (error) {
      throw ExportException(AppStrings.failedToCopyInputVideo(error.message));
    }
  }

  Future<String> _prepareGifCycle({
    required ExportRequest request,
    required String forwardClip,
    required String reverseClip,
    required String concatList,
    required String cycleClip,
    required Duration clipDuration,
    required ProgressCallback onProgress,
  }) async {
    if (request.loopMode == LoopMode.forward) {
      return forwardClip;
    }

    onProgress(0.38, AppStrings.generatingReverseClip);
    await _buildReverseClip(
      forwardClip: forwardClip,
      reverseClip: reverseClip,
      clipDuration: clipDuration,
      onProgress: (progress, message) {
        onProgress(_normalizeProgress(0.38, 0.16, progress), message);
      },
    );

    final cycleContent =
        '${_concatFileLine(forwardClip)}\n${_concatFileLine(reverseClip)}';
    await File(concatList).writeAsString(cycleContent);

    onProgress(0.55, AppStrings.gifSingleCycleGenerating);
    await _runFfmpeg(
      <String>[
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        concatList,
        '-an',
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        cycleClip,
      ],
      expectedDurationSeconds: (clipDuration.inMilliseconds / 1000) * 2,
      onStepProgress: (progress) {
        onProgress(_normalizeProgress(0.55, 0.09, progress), AppStrings.gifSingleCycleGenerating);
      },
    );

    return cycleClip;
  }

  Future<void> _buildReverseClip({
    required String forwardClip,
    required String reverseClip,
    required Duration clipDuration,
    required void Function(double progress, String message) onProgress,
  }) async {
    await _runFfmpeg(
      <String>[
        '-y',
        '-i',
        forwardClip,
        '-an',
        '-vf',
        'reverse,trim=start_frame=1,setpts=PTS-STARTPTS',
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        reverseClip,
      ],
      expectedDurationSeconds: clipDuration.inMilliseconds / 1000,
      onStepProgress: (progress) {
        onProgress(progress, AppStrings.generatingReverseClip);
      },
    );
  }

  @visibleForTesting
  List<String> buildGifPaletteArgs({
    required String inputPath,
    required String palettePath,
    required int fps,
    required GifQualityPreset qualityPreset,
  }) {
    final filter =
        'fps=$fps,${_gifScaleFilter(qualityPreset)},palettegen=stats_mode=full';
    return <String>['-y', '-i', inputPath, '-vf', filter, palettePath];
  }

  @visibleForTesting
  List<String> buildGifRenderArgs({
    required String inputPath,
    required String palettePath,
    required String outputPath,
    required int fps,
    required GifQualityPreset qualityPreset,
  }) {
    final filter =
        '[0:v]fps=$fps,${_gifScaleFilter(qualityPreset)}[src];'
        '[src][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle[gif]';
    return <String>[
      '-y',
      '-i',
      inputPath,
      '-i',
      palettePath,
      '-filter_complex',
      filter,
      '-map',
      '[gif]',
      '-an',
      '-f',
      'gif',
      '-loop',
      '0',
      outputPath,
    ];
  }

  String _gifScaleFilter(GifQualityPreset qualityPreset) {
    switch (qualityPreset) {
      case GifQualityPreset.low:
        return 'scale=min(200\\,iw):-1:flags=lanczos';
      case GifQualityPreset.medium:
        return 'scale=trunc(iw*0.5/2)*2:-1:flags=lanczos';
      case GifQualityPreset.high:
        return 'scale=iw:-1:flags=lanczos';
    }
  }

  @visibleForTesting
  List<String> buildFrameJpegArgs({required FrameExportRequest request}) {
    return <String>[
      '-y',
      '-ss',
      _formatDurationForFfmpeg(request.position),
      '-i',
      request.inputPath,
      '-map',
      '0:v:0',
      '-frames:v',
      '1',
      '-q:v',
      '2',
      '-f',
      'image2',
      request.outputPath,
    ];
  }

  Future<void> _runFfmpeg(
    List<String> args, {
    required double expectedDurationSeconds,
    required void Function(double progress) onStepProgress,
  }) async {
    if (_useEmbeddedFfmpegKit) {
      onStepProgress(0);
      final session = await FFmpegKit.executeWithArguments(args);
      onStepProgress(1);

      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getAllLogsAsString();
        final failStackTrace = await session.getFailStackTrace();
        throw ExportException(
          '${AppStrings.ffmpegExecutionFailed}\n'
          'returnCode=${returnCode?.getValue() ?? 'unknown'}\n'
          '${_summarizeFfmpegLogs(logs ?? '')}'
          '${_summarizeFailStackTrace(failStackTrace)}',
        );
      }
      return;
    }

    final process = await Process.start(
      ffmpegExecutable,
      args,
      runInShell: true,
    );

    final logBuffer = StringBuffer();
    Future<void> consume(Stream<List<int>> stream) async {
      await for (final rawLine
          in stream.transform(utf8.decoder).transform(const LineSplitter())) {
        logBuffer.writeln(rawLine);
        final timeSeconds = _extractFfmpegTime(rawLine);
        if (timeSeconds != null && expectedDurationSeconds > 0) {
          onStepProgress((timeSeconds / expectedDurationSeconds).clamp(0, 1));
        }
      }
    }

    final stderrFuture = consume(process.stderr);
    final stdoutFuture = consume(process.stdout);

    final exitCode = await process.exitCode;
    await Future.wait(<Future<void>>[stderrFuture, stdoutFuture]);

    if (exitCode != 0) {
      throw ExportException(
        '${AppStrings.ffmpegExecutionFailed}\n${_summarizeFfmpegLogs(logBuffer.toString())}',
      );
    }
  }

  String _resolveInputPath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      throw ExportException(AppStrings.emptyInputVideoPath);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }

    if (uri.scheme.isEmpty) {
      return trimmed;
    }

    if (uri.scheme != 'file') {
      throw ExportException(AppStrings.unsupportedInputPathFormat(trimmed));
    }

    try {
      return uri.toFilePath();
    } catch (_) {
      throw ExportException(AppStrings.failedToParseInputPath(trimmed));
    }
  }

  String _summarizeFfmpegLogs(String logs) {
    final lines = logs
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return AppStrings.failedToGetDetailedLog;
    }

    const hints = <String>[
      'error',
      'failed',
      'invalid',
      'no such file',
      'permission denied',
      'operation not permitted',
      'unknown encoder',
      'unknown decoder',
      'unsupported',
      'unrecognized option',
      'option not found',
      'at least one output file must be specified',
      'could not',
      'unable to',
      'not found',
      'does not contain',
      'av_interleaved_write_frame',
    ];

    final matched = lines.where((line) {
      final lower = line.toLowerCase();
      return hints.any(lower.contains);
    }).toList();

    final source = matched.isNotEmpty ? matched : lines;
    final tail = source.length <= 12
        ? source
        : source.sublist(source.length - 12);
    return tail.join('\n');
  }

  String _summarizeFailStackTrace(String? failStackTrace) {
    if (failStackTrace == null) {
      return '';
    }
    final trimmed = failStackTrace.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return '\nstack=$trimmed';
  }

  Future<void> _ensureToolsAvailable() async {
    if (_toolChecked) {
      return;
    }

    if (_useEmbeddedFfmpegKit) {
      _toolChecked = true;
      return;
    }

    try {
      final ffmpeg = await Process.run(ffmpegExecutable, const <String>[
        '-version',
      ], runInShell: true);
      final ffprobe = await Process.run(ffprobeExecutable, const <String>[
        '-version',
      ], runInShell: true);
      if (ffmpeg.exitCode != 0 || ffprobe.exitCode != 0) {
        throw ExportException(AppStrings.failedToStartFfmpeg);
      }
      _toolChecked = true;
    } on ProcessException {
      throw ExportException(AppStrings.ffmpegNotInstalled);
    }
  }

  String _concatFileLine(String inputPath) {
    final normalized = inputPath.replaceAll('\\', '/').replaceAll("'", "'\\''");
    return "file '$normalized'";
  }

  String _formatDurationForFfmpeg(Duration duration) {
    final totalMs = duration.inMilliseconds;
    final ms = totalMs % 1000;
    final totalSeconds = totalMs ~/ 1000;
    final seconds = totalSeconds % 60;
    final minutes = (totalSeconds ~/ 60) % 60;
    final hours = totalSeconds ~/ 3600;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  double _normalizeProgress(double start, double span, double localProgress) {
    return (start + span * localProgress).clamp(0, 1);
  }

  double? _extractFfmpegTime(String line) {
    final match = RegExp(r'time=(\d+):(\d+):(\d+(?:\.\d+)?)').firstMatch(line);
    if (match == null) {
      return null;
    }
    final hours = double.tryParse(match.group(1) ?? '');
    final minutes = double.tryParse(match.group(2) ?? '');
    final seconds = double.tryParse(match.group(3) ?? '');
    if (hours == null || minutes == null || seconds == null) {
      return null;
    }
    return hours * 3600 + minutes * 60 + seconds;
  }
}
