import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/timeline_thumbnail.dart';

class TimelineThumbnailService {
  TimelineThumbnailService({this.ffmpegExecutable = 'ffmpeg'});

  static const int _iosMaxTargetCount = 30;

  final String ffmpegExecutable;
  final Map<String, Future<List<TimelineThumbnail>>> _inFlightBuilds =
      <String, Future<List<TimelineThumbnail>>>{};

  bool get _useEmbeddedFfmpegKit {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  Future<List<TimelineThumbnail>> buildStrip({
    required String inputPath,
    required Duration duration,
    required double zoomLevel,
    required double viewportWidth,
    required double tileBaseWidth,
    int? targetCountCap,
    String cacheVariant = 'full',
  }) async {
    final sourceFile = File(inputPath);
    if (!sourceFile.existsSync() || duration <= Duration.zero) {
      return const <TimelineThumbnail>[];
    }

    final totalSeconds = duration.inMilliseconds / 1000;
    final targetCount = computeTargetCount(
      viewportWidth: viewportWidth,
      zoomLevel: zoomLevel,
      tileBaseWidth: tileBaseWidth,
    );

    final cacheKey = buildCacheKey(
      inputPath: inputPath,
      fileStamp: sourceFile.lastModifiedSync().millisecondsSinceEpoch,
      durationMs: duration.inMilliseconds,
      zoomLevel: zoomLevel,
      viewportWidth: viewportWidth,
      tileBaseWidth: tileBaseWidth,
      cacheVariant: cacheVariant,
      targetCountCap: targetCountCap,
    );

    final inFlight = _inFlightBuilds[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _buildStripInternal(
      inputPath: inputPath,
      duration: duration,
      zoomLevel: zoomLevel,
      viewportWidth: viewportWidth,
      tileBaseWidth: tileBaseWidth,
      cacheKey: cacheKey,
      totalSeconds: totalSeconds,
      targetCount: targetCount,
      targetCountCap: targetCountCap,
    );
    _inFlightBuilds[cacheKey] = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlightBuilds[cacheKey], future)) {
        _inFlightBuilds.remove(cacheKey);
      }
    }
  }

  Future<List<TimelineThumbnail>> _buildStripInternal({
    required String inputPath,
    required Duration duration,
    required double zoomLevel,
    required double viewportWidth,
    required double tileBaseWidth,
    required String cacheKey,
    required double totalSeconds,
    required int targetCount,
    required int? targetCountCap,
  }) async {
    final cacheRoot = await getTemporaryDirectory();
    final processingInputPath = await _prepareInputForProcessing(
      inputPath,
      cacheRoot,
      cacheKey,
    );
    final stripDir = Directory(
      p.join(cacheRoot.path, 'timeline_cache', cacheKey),
    );
    final manifestFile = File(p.join(stripDir.path, 'manifest.json'));

    if (manifestFile.existsSync()) {
      final cached = _readManifest(manifestFile);
      if (cached.isNotEmpty &&
          cached.every((item) => File(item.path).existsSync())) {
        return cached;
      }
    }

    await stripDir.create(recursive: true);

    var effectiveTargetCount = targetCount;
    if (!kIsWeb && Platform.isIOS) {
      effectiveTargetCount = effectiveTargetCount.clamp(6, _iosMaxTargetCount);
    }
    if (targetCountCap != null) {
      effectiveTargetCount = effectiveTargetCount.clamp(6, targetCountCap);
    }

    final span = totalSeconds / effectiveTargetCount;
    final thumbnails = <TimelineThumbnail>[];

    for (var i = 0; i < effectiveTargetCount; i++) {
      final start = span * i;
      final end = (start + span).clamp(0.0, totalSeconds);
      final jpgOutputPath = p.join(
        stripDir.path,
        'thumb_${i.toString().padLeft(3, '0')}.jpg',
      );
      var outputPath = jpgOutputPath;
      var succeeded = await _runThumbnailCommand(
        <String>[
          '-y',
          '-ss',
          start.toStringAsFixed(3),
          '-i',
          processingInputPath,
          '-frames:v',
          '1',
          '-vf',
          'scale=96:-2',
          '-q:v',
          '18',
          '-f',
          'image2',
          outputPath,
        ],
      );

      if ((!succeeded || !File(outputPath).existsSync()) && _useEmbeddedFfmpegKit) {
        final pngOutputPath = p.join(
          stripDir.path,
          'thumb_${i.toString().padLeft(3, '0')}.png',
        );
        outputPath = pngOutputPath;
        succeeded = await _runThumbnailCommand(
          <String>[
            '-y',
            '-ss',
            start.toStringAsFixed(3),
            '-i',
            processingInputPath,
            '-frames:v',
            '1',
            '-vf',
            'scale=96:-2',
            '-f',
            'image2',
            outputPath,
          ],
        );
      }

      if (succeeded && File(outputPath).existsSync()) {
        thumbnails.add(
          TimelineThumbnail(
            path: outputPath,
            startSecond: start,
            endSecond: end,
          ),
        );
      }
    }

    await manifestFile.writeAsString(
      jsonEncode(thumbnails.map((item) => item.toJson()).toList()),
    );

    return thumbnails;
  }

  Future<String> _prepareInputForProcessing(
    String rawInputPath,
    Directory cacheRoot,
    String cacheKey,
  ) async {
    final resolvedPath = _resolveInputPath(rawInputPath);
    final inputFile = File(resolvedPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input video not found for thumbnails', resolvedPath);
    }

    if (!_useEmbeddedFfmpegKit) {
      return resolvedPath;
    }

    final extension = p.extension(resolvedPath).trim();
    final stagingDir = Directory(p.join(cacheRoot.path, 'timeline_inputs'));
    await stagingDir.create(recursive: true);
    final stagedPath = p.join(
      stagingDir.path,
      'input_$cacheKey${extension.isEmpty ? '.mp4' : extension}',
    );

    if (!p.equals(resolvedPath, stagedPath)) {
      await inputFile.copy(stagedPath);
    }
    return stagedPath;
  }

  String _resolveInputPath(String rawPath) {
    final value = rawPath.trim();
    if (value.startsWith('file://')) {
      return Uri.parse(value).toFilePath();
    }
    return value;
  }

  Future<bool> _runThumbnailCommand(List<String> args) async {
    if (_useEmbeddedFfmpegKit) {
      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      final ok = ReturnCode.isSuccess(returnCode);
      if (!ok) {
        final failStack = await session.getFailStackTrace();
        final logs = await session.getAllLogsAsString();
        final code = returnCode?.getValue();
        debugPrint('[Thumbnail][ffmpeg-kit] command failed: ${args.join(' ')}');
        debugPrint(
          '[Thumbnail][ffmpeg-kit] returnCode: '
          '${code ?? 'null(session not completed or aborted)'}',
        );
        if (failStack != null && failStack.isNotEmpty) {
          debugPrint('[Thumbnail][ffmpeg-kit] stack: $failStack');
        }
        if (logs != null && logs.isNotEmpty) {
          final lines = logs.split('\n');
          final preview = lines.take(20).join('\n');
          debugPrint('[Thumbnail][ffmpeg-kit] logs(head): $preview');
        }
      }
      return ok;
    }

    final result = await Process.run(
      ffmpegExecutable,
      args,
      runInShell: true,
    );
    return result.exitCode == 0;
  }

  @visibleForTesting
  int computeTargetCount({
    required double viewportWidth,
    required double zoomLevel,
    required double tileBaseWidth,
  }) {
    final tilesAtFit = (viewportWidth / tileBaseWidth).round().clamp(1, 1000);
    return (tilesAtFit * zoomLevel).round().clamp(6, 180);
  }

  @visibleForTesting
  String buildCacheKey({
    required String inputPath,
    required int fileStamp,
    required int durationMs,
    required double zoomLevel,
    required double viewportWidth,
    required double tileBaseWidth,
    String cacheVariant = 'full',
    int? targetCountCap,
  }) {
    final viewportBucket = (viewportWidth / 32).round();
    final digest = md5
        .convert(
          utf8.encode(
            '$inputPath|$fileStamp|$durationMs|${zoomLevel.toStringAsFixed(2)}|vb:$viewportBucket|tile:${tileBaseWidth.toStringAsFixed(0)}|v:$cacheVariant|cap:${targetCountCap ?? 'none'}',
          ),
        )
        .toString();
    return digest;
  }

  List<TimelineThumbnail> _readManifest(File manifestFile) {
    try {
      final raw = manifestFile.readAsStringSync();
      final list = jsonDecode(raw);
      if (list is! List) {
        return const <TimelineThumbnail>[];
      }
      return list
          .whereType<Map>()
          .map(
            (item) => TimelineThumbnail.fromJson(item.cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const <TimelineThumbnail>[];
    }
  }
}
