import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/export_format.dart';
import '../../models/gif_export_options.dart';
import '../../models/loop_mode.dart';
import '../../models/timeline_thumbnail.dart';
import '../../services/ffmpeg_cli_video_processor.dart';
import '../../services/file_import_service.dart';
import '../../services/timeline_thumbnail_service.dart';
import '../../state/editor_controller.dart';
import '../widgets/editor_shell.dart';
import '../widgets/playback_transport_bar.dart';
import '../widgets/preview_stage.dart';
import '../widgets/replace_input_dialog.dart';
import '../widgets/timeline_zoom_bar.dart';
import '../widgets/trim_timeline.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.inputPath,
    required this.onCloseRequested,
    required this.onReplaceInputPath,
  });

  final String inputPath;
  final VoidCallback onCloseRequested;
  final ValueChanged<String> onReplaceInputPath;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const double _tileBaseWidth = 96;
  static const double _defaultFrameRate = 30.0;
  static const double _loopBoundaryEpsilonSeconds = 0.03;
  static const double _reverseStepSeconds = 1 / _defaultFrameRate;

  static const String _prefExportFormat = 'export_format';
  static const String _prefLoopCount = 'export_loop_count';
  static const String _prefGifQuality = 'gif_quality';
  static const String _prefGifFps = 'gif_fps';
  static const String _prefImageExportDir = 'image_export_dir';
  static const String _prefVideoExportDir = 'video_export_dir';
  static const String _prefGifExportDir = 'gif_export_dir';
  static const String _prefSaveToPhotoLibrary = 'save_to_photo_library';

  late final Player _player;
  late final VideoController _videoController;
  late final EditorController _editorController;
  late final TimelineThumbnailService _thumbnailService;
  final FileImportService _fileImportService = FileImportService();

  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  final ValueNotifier<double> _playheadNotifier = ValueNotifier<double>(0);

  Timer? _thumbnailDebounce;
  Timer? _reverseTicker;
  Timer? _scrubSeekTimer;

  bool _reverseTickBusy = false;
  bool _isScrubSeekInFlight = false;
  bool _isThumbnailBuildInProgress = false;
  bool _thumbnailBuildPending = false;
  bool _thumbnailBuildPendingForce = false;

  bool _isPlaybackActive = true;
  bool _isReverseDirection = false;
  bool _isSeekingByReverseTicker = false;
  bool _isLoadingThumbnails = false;
  bool _isDraggingReplace = false;
  bool _isScrubbing = false;
  bool _isLoopBoundaryTransitioning = false;

  bool _resumePlaybackAfterScrub = false;
  bool _resumeReverseAfterScrub = false;
  double? _pendingScrubSeconds;

  List<TimelineThumbnail>? _deferredThumbnails;
  double _deferredZoom = -1;
  int _deferredViewportBucket = -1;
  bool _deferredClearLoading = false;

  int _thumbnailGeneration = 0;
  double _timelineViewportWidth = 0;
  double _lastLoadedZoom = -1;
  int _lastLoadedViewportBucket = -1;
  LoopMode _lastLoopMode = LoopMode.forward;
  Duration _lastThumbnailInputDuration = Duration.zero;
  double _lastThumbnailInputZoom = -1;

  List<TimelineThumbnail> _thumbnails = const <TimelineThumbnail>[];

  String? _imageExportDirectory;
  String? _videoExportDirectory;
  String? _gifExportDirectory;
  bool _saveToPhotoLibrary = true;

  bool get _supportsDesktopDrop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();

    _player = Player();
    _videoController = VideoController(_player);
    _editorController = EditorController(
      videoProcessor: FfmpegCliVideoProcessor(),
    );
    _thumbnailService = TimelineThumbnailService();
    _lastLoopMode = _editorController.loopMode;

    _initialize();
    _editorController.addListener(_handleControllerChanged);

    _durationSubscription = _player.stream.duration.listen((duration) {
      if (duration > Duration.zero) {
        _editorController.setTotalDuration(duration);
      }
    });

    _positionSubscription = _player.stream.position.listen((position) async {
      if (_isSeekingByReverseTicker || _isScrubbing) {
        return;
      }

      final currentSeconds = position.inMilliseconds / 1000;
      if ((currentSeconds - _playheadNotifier.value).abs() > 0.06) {
        _playheadNotifier.value = currentSeconds;
      }

      if (!_isPlaybackActive || !_editorController.isAutoLoopEnabled) {
        return;
      }

      final trimStart = _editorController.trimStartSeconds;
      final trimEnd = _editorController.trimEndSeconds;
      if (trimEnd <= trimStart + EditorController.minTrimLengthSeconds) {
        return;
      }
      final boundarySeconds = math.max(
        trimStart,
        trimEnd - _loopBoundaryEpsilonSeconds,
      );

      if (_editorController.loopMode == LoopMode.pingPong) {
        if (!_isReverseDirection && currentSeconds >= boundarySeconds) {
          await _enterReversePhase();
        }
        return;
      }

      if (currentSeconds >= boundarySeconds) {
        await _restartForwardLoop(trimStart);
      }
    });
  }

  Future<void> _initialize() async {
    await _loadExportSettings();
    await _editorController.loadDuration(widget.inputPath);
    _editorController.resetTrimToFullRange();
    _playheadNotifier.value = 0;
    try {
      await _player.open(Media(widget.inputPath));
      await _player.seek(Duration.zero);
      await _player.play();
      _scheduleThumbnailBuild(force: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('動画の読み込みに失敗しました: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Future<void> _loadExportSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final formatName = prefs.getString(_prefExportFormat);
    ExportFormat? format;
    for (final item in ExportFormat.values) {
      if (item.name == formatName) {
        format = item;
        break;
      }
    }
    if (format != null) {
      _editorController.setExportFormat(format);
    }

    _editorController.setLoopCount(prefs.getInt(_prefLoopCount) ?? _editorController.loopCount);

    final qualityName = prefs.getString(_prefGifQuality);
    GifQualityPreset? quality;
    for (final item in GifQualityPreset.values) {
      if (item.name == qualityName) {
        quality = item;
        break;
      }
    }
    if (quality != null) {
      _editorController.setGifQualityPreset(quality);
    }

    final fpsName = prefs.getString(_prefGifFps);
    GifFpsPreset? fps;
    for (final item in GifFpsPreset.values) {
      if (item.name == fpsName) {
        fps = item;
        break;
      }
    }
    if (fps != null) {
      _editorController.setGifFpsPreset(fps);
    }

    _imageExportDirectory = _normalizeDirectory(prefs.getString(_prefImageExportDir));
    _videoExportDirectory = _normalizeDirectory(prefs.getString(_prefVideoExportDir));
    _gifExportDirectory = _normalizeDirectory(prefs.getString(_prefGifExportDir));
    _saveToPhotoLibrary = prefs.getBool(_prefSaveToPhotoLibrary) ?? true;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistExportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefExportFormat, _editorController.exportFormat.name);
    await prefs.setInt(_prefLoopCount, _editorController.loopCount);
    await prefs.setString(_prefGifQuality, _editorController.gifQualityPreset.name);
    await prefs.setString(_prefGifFps, _editorController.gifFpsPreset.name);
    await prefs.setString(_prefImageExportDir, _imageExportDirectory ?? '');
    await prefs.setString(_prefVideoExportDir, _videoExportDirectory ?? '');
    await prefs.setString(_prefGifExportDir, _gifExportDirectory ?? '');
    await prefs.setBool(_prefSaveToPhotoLibrary, _saveToPhotoLibrary);
  }


  String? _normalizeDirectory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }
  void _handleControllerChanged() {
    if (_editorController.totalDuration <= Duration.zero) {
      return;
    }

    if (_lastLoopMode != _editorController.loopMode) {
      _lastLoopMode = _editorController.loopMode;
      if (_editorController.loopMode != LoopMode.pingPong &&
          _isReverseDirection) {
        _stopReverseTicker();
        _isReverseDirection = false;
        if (_isPlaybackActive) {
          unawaited(_player.play());
        }
        if (mounted) setState(() {});
      } else if (_editorController.loopMode == LoopMode.pingPong &&
          _isPlaybackActive &&
          _editorController.isAutoLoopEnabled) {
        final trimStart = _editorController.trimStartSeconds;
        final trimEnd = _editorController.trimEndSeconds;
        final boundary = math.max(
          trimStart,
          trimEnd - _loopBoundaryEpsilonSeconds,
        );
        if (_playheadNotifier.value >= boundary) {
          unawaited(_enterReversePhase());
        }
      }
    }

    final durationChanged =
        _editorController.totalDuration != _lastThumbnailInputDuration;
    final zoomChanged =
        (_editorController.zoomLevel - _lastThumbnailInputZoom).abs() > 0.001;
    if (durationChanged || zoomChanged) {
      _lastThumbnailInputDuration = _editorController.totalDuration;
      _lastThumbnailInputZoom = _editorController.zoomLevel;
      _scheduleThumbnailBuild(force: false);
    }
  }

  void _scheduleThumbnailBuild({required bool force}) {
    _thumbnailDebounce?.cancel();
    _thumbnailDebounce = Timer(
      force ? Duration.zero : const Duration(milliseconds: 260),
      () => _enqueueThumbnailBuild(force: force),
    );
  }

  void _enqueueThumbnailBuild({required bool force}) {
    if (_isThumbnailBuildInProgress) {
      _thumbnailBuildPending = true;
      _thumbnailBuildPendingForce = _thumbnailBuildPendingForce || force;
      return;
    }
    unawaited(_runThumbnailBuild(force: force));
  }

  Future<void> _runThumbnailBuild({required bool force}) async {
    _isThumbnailBuildInProgress = true;
    try {
      await _buildThumbnails(force: force);
    } finally {
      _isThumbnailBuildInProgress = false;
      if (_thumbnailBuildPending) {
        final nextForce = _thumbnailBuildPendingForce;
        _thumbnailBuildPending = false;
        _thumbnailBuildPendingForce = false;
        unawaited(_runThumbnailBuild(force: nextForce));
      }
    }
  }

  Future<void> _buildThumbnails({required bool force}) async {
    if (_timelineViewportWidth <= 0 ||
        _editorController.totalDuration <= Duration.zero) {
      return;
    }

    final viewportBucket = (_timelineViewportWidth / 32).round();
    final zoom = _editorController.zoomLevel;
    if (!force &&
        (zoom - _lastLoadedZoom).abs() < 0.01 &&
        viewportBucket == _lastLoadedViewportBucket) {
      return;
    }

    final generation = ++_thumbnailGeneration;
    if (mounted && !_isScrubbing) {
      setState(() => _isLoadingThumbnails = true);
    } else {
      _isLoadingThumbnails = true;
    }

    try {
      final thumbnails = await _thumbnailService.buildStrip(
        inputPath: widget.inputPath,
        duration: _editorController.totalDuration,
        zoomLevel: zoom,
        viewportWidth: _timelineViewportWidth,
        tileBaseWidth: _tileBaseWidth,
      );

      if (!mounted || generation != _thumbnailGeneration) {
        return;
      }

      if (_isScrubbing) {
        _deferredThumbnails = thumbnails;
        _deferredZoom = zoom;
        _deferredViewportBucket = viewportBucket;
      } else {
        setState(() {
          _thumbnails = thumbnails;
          _lastLoadedZoom = zoom;
          _lastLoadedViewportBucket = viewportBucket;
        });
      }
    } finally {
      if (mounted && generation == _thumbnailGeneration) {
        if (_isScrubbing) {
          _deferredClearLoading = true;
        } else {
          setState(() => _isLoadingThumbnails = false);
        }
      }
    }
  }

  void _applyDeferredThumbnailUpdates() {
    if (!mounted) return;
    if (_deferredThumbnails == null && !_deferredClearLoading) {
      return;
    }

    setState(() {
      if (_deferredThumbnails != null) {
        _thumbnails = _deferredThumbnails!;
        _lastLoadedZoom = _deferredZoom;
        _lastLoadedViewportBucket = _deferredViewportBucket;
      }
      if (_deferredClearLoading) {
        _isLoadingThumbnails = false;
      }
      _deferredThumbnails = null;
      _deferredZoom = -1;
      _deferredViewportBucket = -1;
      _deferredClearLoading = false;
    });
  }

  Future<void> _enterReversePhase() async {
    if (_isLoopBoundaryTransitioning ||
        _isReverseDirection ||
        !_isPlaybackActive ||
        _editorController.loopMode != LoopMode.pingPong ||
        !_editorController.isAutoLoopEnabled) {
      return;
    }

    _isLoopBoundaryTransitioning = true;
    try {
      _isReverseDirection = true;
      if (mounted) setState(() {});
      await _player.pause();
      _startReverseTicker();
    } finally {
      _isLoopBoundaryTransitioning = false;
    }
  }

  Future<void> _restartForwardLoop(double trimStartSeconds) async {
    if (_isLoopBoundaryTransitioning) {
      return;
    }

    _isLoopBoundaryTransitioning = true;
    try {
      _stopReverseTicker();
      _isReverseDirection = false;

      final target = _clampToDuration(trimStartSeconds);
      _isSeekingByReverseTicker = true;
      await _player.seek(Duration(milliseconds: (target * 1000).round()));
      _isSeekingByReverseTicker = false;

      _playheadNotifier.value = target;
      _editorController.setPlayheadFromScrub(target);

      if (_isPlaybackActive) {
        await _player.play();
      }
      if (mounted) setState(() {});
    } finally {
      _isSeekingByReverseTicker = false;
      _isLoopBoundaryTransitioning = false;
    }
  }

  void _startReverseTicker() {
    if (_reverseTicker != null) {
      return;
    }

    _reverseTicker = Timer.periodic(const Duration(milliseconds: 33), (
      _,
    ) async {
      if (!_isPlaybackActive || !_isReverseDirection) {
        return;
      }
      if (_editorController.loopMode != LoopMode.pingPong ||
          !_editorController.isAutoLoopEnabled) {
        _stopReverseTicker();
        return;
      }
      if (_reverseTickBusy) {
        return;
      }

      _reverseTickBusy = true;
      try {
        final trimStart = _editorController.trimStartSeconds;
        final trimEnd = _editorController.trimEndSeconds;

        final current = _playheadNotifier.value.clamp(trimStart, trimEnd);
        final next = (current - _reverseStepSeconds)
            .clamp(trimStart, trimEnd)
            .toDouble();

        _isSeekingByReverseTicker = true;
        await _player.seek(Duration(milliseconds: (next * 1000).round()));
        _playheadNotifier.value = next;
        _editorController.setPlayheadFromScrub(next);
        _isSeekingByReverseTicker = false;

        if (next <= trimStart + _loopBoundaryEpsilonSeconds) {
          _isSeekingByReverseTicker = true;
          await _player.seek(
            Duration(milliseconds: (trimStart * 1000).round()),
          );
          _playheadNotifier.value = trimStart;
          _editorController.setPlayheadFromScrub(trimStart);
          _isSeekingByReverseTicker = false;
          _isReverseDirection = false;
          _stopReverseTicker();
          if (_isPlaybackActive) {
            await _player.play();
          }
          if (mounted) setState(() {});
        }
      } finally {
        _isSeekingByReverseTicker = false;
        _reverseTickBusy = false;
      }
    });
  }

  void _stopReverseTicker() {
    _reverseTicker?.cancel();
    _reverseTicker = null;
    _isSeekingByReverseTicker = false;
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaybackActive) {
      _isPlaybackActive = false;
      _stopReverseTicker();
      await _player.pause();
    } else {
      _isPlaybackActive = true;
      final trimStart = _editorController.trimStartSeconds;
      final trimEnd = _editorController.trimEndSeconds;
      final boundary = math.max(
        trimStart,
        trimEnd - _loopBoundaryEpsilonSeconds,
      );
      if (_editorController.loopMode == LoopMode.pingPong &&
          _isReverseDirection) {
        await _player.pause();
        _startReverseTicker();
      } else if (_editorController.loopMode == LoopMode.pingPong &&
          _playheadNotifier.value >= boundary &&
          _editorController.isAutoLoopEnabled) {
        await _enterReversePhase();
      } else {
        await _player.play();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _jumpToTrimStart() async {
    await _seekTo(_editorController.trimStartSeconds);
  }

  Future<void> _jumpToTrimEnd() async {
    await _seekTo(_editorController.trimEndSeconds);
  }

  Future<void> _stepFrame({required bool forward}) async {
    final step = 1 / _defaultFrameRate;
    final delta = forward ? step : -step;
    await _seekTo(_playheadNotifier.value + delta);
  }

  Future<void> _setTrimBoundaryAtPlayhead({required bool isStart}) async {
    final playhead = _playheadNotifier.value;
    final start = _editorController.trimStartSeconds;
    final end = _editorController.trimEndSeconds;

    if (isStart) {
      final nextStart = playhead
          .clamp(0.0, end - EditorController.minTrimLengthSeconds)
          .toDouble();
      _editorController.setTrimRange(startSeconds: nextStart, endSeconds: end);
      await _seekTo(_playheadNotifier.value.clamp(nextStart, end).toDouble());
      return;
    }

    final maxSeconds = _editorController.totalDuration.inMilliseconds / 1000;
    final nextEnd = playhead
        .clamp(start + EditorController.minTrimLengthSeconds, maxSeconds)
        .toDouble();
    _editorController.setTrimRange(startSeconds: start, endSeconds: nextEnd);
    await _seekTo(_playheadNotifier.value.clamp(start, nextEnd).toDouble());
  }

  double _clampToDuration(double seconds) {
    final maxSeconds = _editorController.totalDuration.inMilliseconds / 1000;
    if (maxSeconds <= 0) {
      return 0;
    }
    return seconds.clamp(0.0, maxSeconds).toDouble();
  }

  void _handleScrubStart() {
    if (_editorController.isExporting || _isScrubbing) {
      return;
    }
    _isScrubbing = true;
    _isLoopBoundaryTransitioning = false;
    _resumePlaybackAfterScrub = _isPlaybackActive;
    _resumeReverseAfterScrub = _isReverseDirection;
    _pendingScrubSeconds = null;

    _stopReverseTicker();
    unawaited(_player.pause());
  }

  void _handleScrubUpdate(double seconds) {
    if (_editorController.isExporting || !_isScrubbing) {
      return;
    }
    final target = _clampToDuration(seconds);
    _playheadNotifier.value = target;
    _pendingScrubSeconds = target;
    _startScrubSeekTimer();
  }

  void _startScrubSeekTimer() {
    _scrubSeekTimer ??= Timer.periodic(const Duration(milliseconds: 24), (_) {
      unawaited(_flushScrubSeek());
    });
  }

  Future<void> _flushScrubSeek() async {
    if (_isScrubSeekInFlight) {
      return;
    }

    final target = _pendingScrubSeconds;
    if (target == null) {
      if (!_isScrubbing) {
        _scrubSeekTimer?.cancel();
        _scrubSeekTimer = null;
      }
      return;
    }

    _pendingScrubSeconds = null;
    _isScrubSeekInFlight = true;
    try {
      await _player.seek(Duration(milliseconds: (target * 1000).round()));
    } finally {
      _isScrubSeekInFlight = false;
      if (_pendingScrubSeconds != null) {
        unawaited(_flushScrubSeek());
      } else if (!_isScrubbing) {
        _scrubSeekTimer?.cancel();
        _scrubSeekTimer = null;
      }
    }
  }

  Future<void> _handleScrubEnd(double seconds) async {
    if (!_isScrubbing) {
      return;
    }

    final target = _clampToDuration(seconds);
    _isScrubbing = false;
    _pendingScrubSeconds = target;
    await _flushScrubSeek();

    _scrubSeekTimer?.cancel();
    _scrubSeekTimer = null;

    _playheadNotifier.value = target;
    _editorController.setPlayheadFromScrub(target);

    _isReverseDirection = false;
    if (_resumePlaybackAfterScrub) {
      if (_editorController.loopMode == LoopMode.pingPong &&
          _resumeReverseAfterScrub) {
        _isReverseDirection = true;
        _startReverseTicker();
      } else {
        await _player.play();
      }
    }

    _applyDeferredThumbnailUpdates();
    if (mounted) setState(() {});
  }

  Future<void> _seekTo(double seconds) async {
    final target = _clampToDuration(seconds);
    _stopReverseTicker();
    _isLoopBoundaryTransitioning = false;
    _isReverseDirection = false;

    _playheadNotifier.value = target;
    _editorController.setPlayheadFromScrub(target);
    await _player.seek(Duration(milliseconds: (target * 1000).round()));

    if (_isPlaybackActive) {
      await _player.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleDropReplace(String rawPath) async {
    final err = _fileImportService.validateVideoPath(rawPath);
    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (_editorController.isExporting || _editorController.isFrameExporting) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u66F8\u304D\u51FA\u3057\u4E2D\u306F\u52D5\u753B\u3092\u5207\u308A\u66FF\u3048\u3067\u304D\u307E\u305B\u3093\u3002',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (rawPath == widget.inputPath) {
      return;
    }

    final shouldReplace = await showReplaceInputDialog(context);

    if (shouldReplace) {
      widget.onReplaceInputPath(rawPath);
    }
  }

  Future<void> _startExport(EditorController controller) async {
    final isMobilePhotoLibrary = _isMobilePlatform && _saveToPhotoLibrary;
    final outputPath = await _resolveVideoOutputPath(controller.exportFormat);
    if (outputPath == null) return;

    final success = await controller.export(
      inputPath: widget.inputPath,
      outputPath: outputPath,
    );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      final exportedPath = controller.lastOutputPath;
      if (isMobilePhotoLibrary && exportedPath != null) {
        await _storeExportToGallery(exportedPath, controller.exportFormat.label);
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('書き出しが完了しました。'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (controller.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportCurrentFrame(EditorController controller) async {
    final isMobilePhotoLibrary = _isMobilePlatform && _saveToPhotoLibrary;
    final outputPath = await _resolveFrameOutputPath();
    if (outputPath == null) {
      return;
    }

    final success = await controller.exportCurrentFrameJpeg(
      inputPath: widget.inputPath,
      positionSeconds: _playheadNotifier.value,
      outputPath: outputPath,
    );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (!success) {
      if (controller.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final framePath = controller.lastFrameOutputPath;
    if (framePath == null) {
      return;
    }

    if (isMobilePhotoLibrary) {
      await _storeFrameToGallery(framePath);
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('フレーム画像を書き出しました: $framePath'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _storeFrameToGallery(String imagePath) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await File(imagePath).readAsBytes();
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: p.basenameWithoutExtension(imagePath),
      );
      final isSuccess =
          (result['isSuccess'] == true) || (result['success'] == true);
      if (!isSuccess) {
        throw Exception('保存処理が失敗しました。');
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            '\u30D5\u30EC\u30FC\u30E0\u753B\u50CF\u3092\u30D5\u30A9\u30C8\u30E9\u30A4\u30D6\u30E9\u30EA\u306B\u4FDD\u5B58\u3057\u307E\u3057\u305F\u3002',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '\u30D5\u30A9\u30C8\u30E9\u30A4\u30D6\u30E9\u30EA\u4FDD\u5B58\u306B\u5931\u6557\u3057\u307E\u3057\u305F: $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Future<void> _storeExportToGallery(String filePath, String formatLabel) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ImageGallerySaver.saveFile(filePath);
      final isSuccess =
          (result['isSuccess'] == true) || (result['success'] == true);
      if (!isSuccess) {
        throw Exception('保存処理が失敗しました。');
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('$formatLabel を写真ライブラリに保存しました。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('写真ライブラリ保存に失敗しました: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _resolveVideoOutputPath(ExportFormat format) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');
    final name = 'loop_$timestamp.${format.extension}';

    if (_isMobilePlatform && _saveToPhotoLibrary) {
      final tempDir = await getTemporaryDirectory();
      return p.join(tempDir.path, name);
    }

    final directory = format == ExportFormat.gif ? _gifExportDirectory : _videoExportDirectory;
    if (directory == null || directory.trim().isEmpty) {
      _showPathRequiredMessage();
      return null;
    }
    return p.join(directory, name);
  }

  Future<String?> _resolveFrameOutputPath() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');
    final name = 'frame_$timestamp.jpg';

    if (_isMobilePlatform && _saveToPhotoLibrary) {
      final tempDir = await getTemporaryDirectory();
      return p.join(tempDir.path, name);
    }

    final directory = _imageExportDirectory;
    if (directory == null || directory.trim().isEmpty) {
      _showPathRequiredMessage();
      return null;
    }
    return p.join(directory, name);
  }

  void _showPathRequiredMessage() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('保存先パスを設定してください。'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectDirectory(ValueSetter<String?> onChanged) async {
    final selected = await FilePicker.platform.getDirectoryPath(dialogTitle: '保存先フォルダを選択');
    if (selected == null || selected.isEmpty) {
      return;
    }
    onChanged(selected);
    await _persistExportSettings();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _thumbnailDebounce?.cancel();
    _scrubSeekTimer?.cancel();
    _stopReverseTicker();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _editorController.removeListener(_handleControllerChanged);
    _playheadNotifier.dispose();
    _player.dispose();
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EditorController>.value(
      value: _editorController,
      child: Consumer<EditorController>(
        builder: (context, controller, child) {
          return ValueListenableBuilder<double>(
            valueListenable: _playheadNotifier,
            builder: (context, playheadSeconds, _) {
              final playheadDuration = Duration(
                milliseconds: (playheadSeconds * 1000).round(),
              );
              final trimSummary =
                  'start ${controller.trimStartSeconds.toStringAsFixed(2)}s / end ${controller.trimEndSeconds.toStringAsFixed(2)}s';

              Widget shell = EditorShell(
                title: p.basename(widget.inputPath),
                onCloseRequested: widget.onCloseRequested,
                showDropHighlight: _isDraggingReplace,
                preview: PreviewStage(
                  video: Video(
                    controller: _videoController,
                    controls: NoVideoControls,
                  ),
                  positionLabel:
                      '${_formatDuration(playheadDuration)}  ($trimSummary)',
                  isPingPong: controller.loopMode == LoopMode.pingPong,
                  isReverseDirection: _isReverseDirection,
                  bottomOverlay: PlaybackTransportBar(
                    isPlaying: _isPlaybackActive,
                    isDisabled:
                        controller.isExporting ||
                        controller.totalDuration <= Duration.zero,
                    onSetStart: () {
                      unawaited(_setTrimBoundaryAtPlayhead(isStart: true));
                    },
                    onJumpStart: () {
                      unawaited(_jumpToTrimStart());
                    },
                    onStepPrev: () {
                      unawaited(_stepFrame(forward: false));
                    },
                    onPlayPause: () {
                      unawaited(_togglePlayPause());
                    },
                    onStepNext: () {
                      unawaited(_stepFrame(forward: true));
                    },
                    onJumpEnd: () {
                      unawaited(_jumpToTrimEnd());
                    },
                    onSetEnd: () {
                      unawaited(_setTrimBoundaryAtPlayhead(isStart: false));
                    },
                  ),
                ),
                timeline: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_isLoadingThumbnails)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Expanded(
                      child: TrimTimeline(
                        totalDuration: controller.totalDuration,
                        trimStartSeconds: controller.trimStartSeconds,
                        trimEndSeconds: controller.trimEndSeconds,
                        playheadSeconds: playheadSeconds,
                        zoomLevel: controller.zoomLevel,
                        tileBaseWidth: _tileBaseWidth,
                        thumbnails: _thumbnails,
                        onViewportWidthChanged: (width) {
                          if ((width - _timelineViewportWidth).abs() < 1) {
                            return;
                          }
                          _timelineViewportWidth = width;
                          _scheduleThumbnailBuild(force: true);
                        },
                        onSeek: (seconds) {
                          if (controller.isExporting) {
                            return;
                          }
                          unawaited(_seekTo(seconds));
                        },
                        onScrubStart: controller.isExporting
                            ? null
                            : _handleScrubStart,
                        onScrubUpdate: controller.isExporting
                            ? null
                            : _handleScrubUpdate,
                        onScrubEnd: controller.isExporting
                            ? null
                            : (seconds) {
                                unawaited(_handleScrubEnd(seconds));
                              },
                        onTrimChanged: (start, end) {
                          controller.setTrimRange(
                            startSeconds: start,
                            endSeconds: end,
                          );
                          if (playheadSeconds < start ||
                              playheadSeconds > end) {
                            final target = _clampToDuration(start);
                            _playheadNotifier.value = target;
                            _pendingScrubSeconds = target;
                            _startScrubSeekTimer();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TimelineZoomBar(
                      zoomLevel: controller.zoomLevel,
                      onChanged: controller.isExporting
                          ? null
                          : (value) => controller.setZoomLevel(value),
                    ),
                  ],
                ),
                controls: _buildControlPanel(context, controller),
              );

              if (_supportsDesktopDrop) {
                shell = DropTarget(
                  onDragEntered: (_) =>
                      setState(() => _isDraggingReplace = true),
                  onDragExited: (_) =>
                      setState(() => _isDraggingReplace = false),
                  onDragDone: (details) async {
                    setState(() => _isDraggingReplace = false);
                    if (details.files.isEmpty) {
                      return;
                    }
                    await _handleDropReplace(details.files.first.path);
                  },
                  child: shell,
                );
              }

              return shell;
            },
          );
        },
      ),
    );
  }


  Future<void> _showExportSettingsModal(EditorController controller) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('書き出し設定'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButtonFormField<ExportFormat>(
                        value: controller.exportFormat,
                        decoration: const InputDecoration(labelText: '書き出し形式'),
                        items: ExportFormat.values
                            .map((format) => DropdownMenuItem<ExportFormat>(value: format, child: Text(format.label)))
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          controller.setExportFormat(value);
                          await _persistExportSettings();
                          setModalState(() {});
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('ループ回数'),
                      Slider(
                        value: controller.loopCount.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        label: '${controller.loopCount}',
                        onChanged: (value) async {
                          controller.setLoopCount(value.round());
                          await _persistExportSettings();
                          setModalState(() {});
                          if (mounted) setState(() {});
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('${controller.loopCount}回'),
                      ),
                      const Divider(height: 24),
                      DropdownButtonFormField<GifQualityPreset>(
                        value: controller.gifQualityPreset,
                        decoration: const InputDecoration(labelText: 'GIF品質'),
                        items: GifQualityPreset.values
                            .map((preset) => DropdownMenuItem<GifQualityPreset>(value: preset, child: Text(preset.label)))
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          controller.setGifQualityPreset(value);
                          await _persistExportSettings();
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<GifFpsPreset>(
                        value: controller.gifFpsPreset,
                        decoration: const InputDecoration(labelText: 'GIF FPS'),
                        items: GifFpsPreset.values
                            .map((preset) => DropdownMenuItem<GifFpsPreset>(value: preset, child: Text(preset.label)))
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          controller.setGifFpsPreset(value);
                          await _persistExportSettings();
                          setModalState(() {});
                        },
                      ),
                      const Divider(height: 24),
                      _buildPathSettingRow(
                        label: '画像書き出しパス',
                        value: _imageExportDirectory,
                        enabled: !(_isMobilePlatform && _saveToPhotoLibrary),
                        onPick: () => _selectDirectory((value) => _imageExportDirectory = value),
                      ),
                      const SizedBox(height: 8),
                      _buildPathSettingRow(
                        label: '動画書き出しパス',
                        value: _videoExportDirectory,
                        enabled: !(_isMobilePlatform && _saveToPhotoLibrary),
                        onPick: () => _selectDirectory((value) => _videoExportDirectory = value),
                      ),
                      const SizedBox(height: 8),
                      _buildPathSettingRow(
                        label: 'GIF書き出しパス',
                        value: _gifExportDirectory,
                        enabled: !(_isMobilePlatform && _saveToPhotoLibrary),
                        onPick: () => _selectDirectory((value) => _gifExportDirectory = value),
                      ),
                      if (_isMobilePlatform) ...<Widget>[
                        const Divider(height: 24),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('写真ライブラリに直接保存'),
                          value: _saveToPhotoLibrary,
                          onChanged: (value) async {
                            _saveToPhotoLibrary = value;
                            await _persistExportSettings();
                            setModalState(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPathSettingRow({
    required String label,
    required String? value,
    required bool enabled,
    required VoidCallback onPick,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextFormField(
            initialValue: value ?? '',
            enabled: false,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              hintText: enabled ? '未設定' : '写真ライブラリ保存時は無効',
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: enabled ? onPick : null,
          child: const Text('選択'),
        ),
      ],
    );
  }

  Widget _buildControlPanel(BuildContext context, EditorController controller) {
    final iosUnsupported = defaultTargetPlatform == TargetPlatform.iOS;
    final exportActionDisabled =
        controller.isExporting ||
        controller.isFrameExporting ||
        controller.totalDuration <= Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          runSpacing: 8,
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SegmentedButton<LoopMode>(
              segments: LoopMode.values
                  .map(
                    (mode) => ButtonSegment<LoopMode>(
                      value: mode,
                      label: Text(mode.label),
                    ),
                  )
                  .toList(),
              selected: <LoopMode>{controller.loopMode},
              onSelectionChanged: exportActionDisabled
                  ? null
                  : (selection) => controller.setLoopMode(selection.first),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('\u7BC4\u56F2\u30EB\u30FC\u30D7'),
                Switch(
                  value: controller.isAutoLoopEnabled,
                  onChanged: exportActionDisabled
                      ? null
                      : controller.setAutoLoopEnabled,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                SizedBox(
                  width: 260,
                  child: OutlinedButton.icon(
                    onPressed: exportActionDisabled || iosUnsupported
                        ? null
                        : () => _exportCurrentFrame(controller),
                    icon: const Icon(Icons.image_rounded),
                    label: const Text(
                      '\u3053\u306E\u30D5\u30EC\u30FC\u30E0\u3092\u753B\u50CF\u66F8\u304D\u51FA\u3057',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: exportActionDisabled || iosUnsupported
                          ? null
                          : () => _startExport(controller),
                      icon: const Icon(Icons.movie_creation_rounded),
                      label: const Text('書き出し'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '書き出し設定',
                      onPressed: exportActionDisabled
                          ? null
                          : () => _showExportSettingsModal(controller),
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (iosUnsupported) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '\u0069\u004F\u0053\u3067\u306F\u0046\u0046\u006D\u0070\u0065\u0067\u0020\u0043\u004C\u0049\u672A\u5BFE\u5FDC\u306E\u305F\u3081\u3001\u66F8\u304D\u51FA\u3057\u306F\u73FE\u72B6\u7121\u52B9\u3067\u3059\u3002',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (controller.isExporting ||
            controller.isFrameExporting ||
            controller.exportProgress > 0) ...<Widget>[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: controller.isExporting && controller.exportProgress == 0
                ? null
                : controller.exportProgress,
          ),
          const SizedBox(height: 6),
          Text(
            controller.isFrameExporting
                ? '\u30D5\u30EC\u30FC\u30E0\u753B\u50CF\u3092\u66F8\u304D\u51FA\u3057\u4E2D...'
                : '${(controller.exportProgress * 100).toStringAsFixed(0)}% ${controller.exportMessage}',
          ),
        ],
        if (controller.lastOutputPath != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '\u51FA\u529B\u5148: ${controller.lastOutputPath}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => OpenFilex.open(controller.lastOutputPath!),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('\u4FDD\u5B58\u5148\u3092\u958B\u304F'),
            ),
          ),
        ],
        if (controller.lastFrameOutputPath != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '\u753B\u50CF\u51FA\u529B\u5148: ${controller.lastFrameOutputPath}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_isDesktopPlatform)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    OpenFilex.open(controller.lastFrameOutputPath!),
                icon: const Icon(Icons.image_search_rounded),
                label: const Text('\u753B\u50CF\u3092\u958B\u304F'),
              ),
            ),
        ],
        if (controller.errorMessage != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            controller.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
