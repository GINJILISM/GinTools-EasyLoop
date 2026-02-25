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

  final String ffmpegExecutable;

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
    );

    final cacheRoot = await getTemporaryDirectory();
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

    final span = totalSeconds / targetCount;
    final thumbnails = <TimelineThumbnail>[];

    for (var i = 0; i < targetCount; i++) {
      final start = span * i;
      final end = (start + span).clamp(0.0, totalSeconds);
      final outputPath = p.join(
        stripDir.path,
        'thumb_${i.toString().padLeft(3, '0')}.jpg',
      );

      final args = <String>[
        '-y',
        '-ss',
        start.toStringAsFixed(3),
        '-i',
        inputPath,
        '-frames:v',
        '1',
        '-vf',
        'scale=96:-2',
        '-q:v',
        '18',
        outputPath,
      ];

      final succeeded = await _runThumbnailCommand(args);

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

  Future<bool> _runThumbnailCommand(List<String> args) async {
    if (_useEmbeddedFfmpegKit) {
      final session = await FFmpegKit.executeWithArgumentsAsync(args);
      final returnCode = await session.getReturnCode();
      return ReturnCode.isSuccess(returnCode);
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
  }) {
    final viewportBucket = (viewportWidth / 32).round();
    final digest = md5
        .convert(
          utf8.encode(
            '$inputPath|$fileStamp|$durationMs|${zoomLevel.toStringAsFixed(2)}|vb:$viewportBucket|tile:${tileBaseWidth.toStringAsFixed(0)}',
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
