import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/export_format.dart';
import '../models/loop_mode.dart';
import 'video_processor.dart';

class FfmpegCliVideoProcessor implements VideoProcessor {
  FfmpegCliVideoProcessor({
    this.ffmpegExecutable = 'ffmpeg',
    this.ffprobeExecutable = 'ffprobe',
  });

  static const int _gifFps = 15;
  static const int _gifMaxWidth = 960;

  final String ffmpegExecutable;
  final String ffprobeExecutable;
  bool _toolChecked = false;

  @override
  Future<Duration> probeDuration(String inputPath) async {
    await _ensureToolsAvailable();
    final result = await Process.run(ffprobeExecutable, <String>[
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      inputPath,
    ], runInShell: true);

    if (result.exitCode != 0) {
      throw ExportException('動画長さの解析に失敗しました。ffprobeの設定を確認してください。');
    }

    final raw = (result.stdout as String).trim();
    final seconds = double.tryParse(raw);
    if (seconds == null || seconds <= 0) {
      throw ExportException('動画の長さを取得できませんでした。');
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
      throw ExportException('開始点と終了点の範囲が不正です。');
    }
    if (request.loopCount < 1) {
      throw ExportException('ループ回数は1以上で指定してください。');
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

    final forwardClip = p.join(workDir.path, 'forward.mp4');
    final reverseClip = p.join(workDir.path, 'reverse.mp4');
    final concatList = p.join(workDir.path, 'concat.txt');
    final cycleClip = p.join(workDir.path, 'cycle.mp4');
    final palettePath = p.join(workDir.path, 'palette.png');

    try {
      onProgress(0.02, 'トリミング中...');
      await _runFfmpeg(
        <String>[
          '-y',
          '-i',
          request.inputPath,
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
          onProgress(_normalizeProgress(0.02, 0.30, progress), 'トリミング中...');
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

        onProgress(0.65, 'GIFパレット生成中...');
        await _runFfmpeg(
          buildGifPaletteArgs(inputPath: cycleInput, palettePath: palettePath),
          expectedDurationSeconds: clipDuration.inMilliseconds / 1000,
          onStepProgress: (progress) {
            onProgress(
              _normalizeProgress(0.65, 0.12, progress),
              'GIFパレット生成中...',
            );
          },
        );

        onProgress(0.78, 'GIFエンコード中...');
        await _runFfmpeg(
          buildGifRenderArgs(
            inputPath: cycleInput,
            palettePath: palettePath,
            outputPath: request.outputPath,
          ),
          expectedDurationSeconds: clipDuration.inMilliseconds / 1000,
          onStepProgress: (progress) {
            onProgress(
              _normalizeProgress(0.78, 0.21, progress),
              'GIFエンコード中...',
            );
          },
        );

        onProgress(1, '書き出し完了');
        return request.outputPath;
      }

      if (request.loopMode == LoopMode.forward) {
        final listContent = List<String>.generate(
          request.loopCount,
          (_) => _concatFileLine(forwardClip),
        ).join('\n');
        await File(concatList).writeAsString(listContent);

        onProgress(0.38, '連結中...');
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
            onProgress(_normalizeProgress(0.38, 0.61, progress), '連結中...');
          },
        );
      } else {
        onProgress(0.38, '逆再生クリップ生成中...');
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

        onProgress(0.60, 'ピンポン連結中...');
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
            onProgress(_normalizeProgress(0.60, 0.39, progress), 'ピンポン連結中...');
          },
        );
      }

      onProgress(1, '書き出し完了');
      return request.outputPath;
    } on ProcessException {
      throw ExportException('FFmpegが見つかりません。PATHにffmpeg/ffprobeを追加してください。');
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

    await _runFfmpeg(
      buildFrameJpegArgs(request: request),
      expectedDurationSeconds: 1,
      onStepProgress: (_) {},
    );

    return request.outputPath;
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

    onProgress(0.38, '逆再生クリップ生成中...');
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

    onProgress(0.55, 'GIF 1サイクル生成中...');
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
        onProgress(_normalizeProgress(0.55, 0.09, progress), 'GIF 1サイクル生成中...');
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
        onProgress(progress, '逆再生クリップ生成中...');
      },
    );
  }

  @visibleForTesting
  List<String> buildGifPaletteArgs({
    required String inputPath,
    required String palettePath,
    int fps = _gifFps,
    int maxWidth = _gifMaxWidth,
  }) {
    final filter =
        'fps=$fps,scale=min($maxWidth\\,iw):-1:flags=lanczos,palettegen=stats_mode=diff';
    return <String>['-y', '-i', inputPath, '-vf', filter, palettePath];
  }

  @visibleForTesting
  List<String> buildGifRenderArgs({
    required String inputPath,
    required String palettePath,
    required String outputPath,
    int fps = _gifFps,
    int maxWidth = _gifMaxWidth,
  }) {
    final filter =
        '[0:v]fps=$fps,scale=min($maxWidth\\,iw):-1:flags=lanczos[x];'
        '[x][1:v]paletteuse=dither=sierra2_4a';
    return <String>[
      '-y',
      '-i',
      inputPath,
      '-i',
      palettePath,
      '-lavfi',
      filter,
      '-loop',
      '0',
      outputPath,
    ];
  }

  @visibleForTesting
  List<String> buildFrameJpegArgs({required FrameExportRequest request}) {
    return <String>[
      '-y',
      '-i',
      request.inputPath,
      '-ss',
      _formatDurationForFfmpeg(request.position),
      '-frames:v',
      '1',
      '-q:v',
      '1',
      '-qmin',
      '1',
      '-qmax',
      '1',
      '-pix_fmt',
      'yuvj444p',
      request.outputPath,
    ];
  }

  Future<void> _runFfmpeg(
    List<String> args, {
    required double expectedDurationSeconds,
    required void Function(double progress) onStepProgress,
  }) async {
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
      final lines = logBuffer
          .toString()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final tail = lines.length <= 10
          ? lines.join('\n')
          : lines.sublist(lines.length - 10).join('\n');
      throw ExportException('FFmpegの実行に失敗しました。\n$tail');
    }
  }

  Future<void> _ensureToolsAvailable() async {
    if (_toolChecked) {
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
        throw ExportException('ffmpeg/ffprobe の起動に失敗しました。');
      }
      _toolChecked = true;
    } on ProcessException {
      throw ExportException('ffmpeg/ffprobe が見つかりません。インストール後に再実行してください。');
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
