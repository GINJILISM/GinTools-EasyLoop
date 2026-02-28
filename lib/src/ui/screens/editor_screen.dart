import 'dart:async';
import 'dart:io';

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
import 'package:url_launcher/url_launcher.dart';

import '../../models/export_format.dart';
import '../../models/gif_export_options.dart';
import '../../models/loop_mode.dart';
import '../../models/timeline_thumbnail.dart';
import '../../services/ffmpeg_cli_video_processor.dart';
import '../../services/file_import_service.dart';
import '../../services/output_file_naming_service.dart';
import '../../services/timeline_thumbnail_service.dart';
import '../../state/editor_controller.dart';
import '../liquid_glass/liquid_glass_refs.dart';
import '../widgets/editor_shell.dart';
import '../widgets/interactive_liquid_glass_icon_button.dart';
import '../widgets/liquid_glass_action_button.dart';
import '../widgets/playback_transport_bar.dart';
import '../widgets/preview_stage.dart';
import '../widgets/replace_input_dialog.dart';
import '../widgets/loop_mode_glass_tabs.dart';
import '../widgets/timeline_zoom_bar.dart';
import '../widgets/trim_timeline.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.inputPath,
    required this.onRequestOpenFromFiles,
    required this.onRequestOpenFromLibrary,
    required this.onReplaceInputPath,
    this.pickDirectoryOverride,
  });

  final String inputPath;
  final Future<void> Function() onRequestOpenFromFiles;
  final Future<void> Function() onRequestOpenFromLibrary;
  final ValueChanged<String> onReplaceInputPath;
  final Future<String?> Function(String dialogTitle)? pickDirectoryOverride;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const double _tileBaseWidth = 96;
  static const double _defaultFrameRate = 30.0;
  static const double _reverseStartBoundaryEpsilonSeconds = 0.03;
  static const double _reverseStepSeconds = 1 / _defaultFrameRate;
  static const int _initialMobileThumbnailCount = 8;
  static const Duration _slowOpenIndicatorDelay = Duration(seconds: 2);

  static const String _prefExportFormat = 'export_format';
  static const String _prefLoopCount = 'export_loop_count';
  static const String _prefGifQuality = 'gif_quality';
  static const String _prefGifFps = 'gif_fps';
  static const String _prefImageExportDir = 'image_export_dir';
  static const String _prefVideoExportDir = 'video_export_dir';
  static const String _prefGifExportDir = 'gif_export_dir';
  static const String _prefSaveToPhotoLibrary = 'save_to_photo_library';
  static const String _prefOutputNameTemplate = 'output_name_template';

  late final Player _player;
  late final VideoController _videoController;
  late final EditorController _editorController;
  late final TimelineThumbnailService _thumbnailService;
  final OutputFileNamingService _outputFileNamingService =
      OutputFileNamingService();
  final FileImportService _fileImportService = FileImportService();

  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _completedSubscription;

  final ValueNotifier<double> _playheadNotifier = ValueNotifier<double>(0);

  Timer? _thumbnailDebounce;
  Timer? _reverseTicker;
  Timer? _scrubSeekTimer;
  Timer? _settingsPersistDebounce;
  Timer? _durationProbeFallbackTimer;
  Timer? _slowOpenIndicatorTimer;

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
  bool _quickThumbnailPhaseCompleted = false;
  bool _isSlowOpeningVisible = false;

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
  String _outputNameTemplate = OutputFileNamingService.defaultTemplate;
  bool _saveToPhotoLibrary = true;
  bool _lastVideoExportToPhotoLibrary = false;
  bool _lastFrameExportToPhotoLibrary = false;

  bool get _supportsDesktopDrop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  SnackBarBehavior get _snackBarBehavior =>
      _isMobilePlatform ? SnackBarBehavior.fixed : SnackBarBehavior.floating;

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
        _durationProbeFallbackTimer?.cancel();
        _editorController.setTotalDuration(duration);
      }
    });

    _positionSubscription = _player.stream.position.listen((position) async {
      if (_isSeekingByReverseTicker || _isScrubbing) {
        return;
      }

      final currentSeconds = position.inMilliseconds / 1000;
      final playheadDeltaThreshold =
          LiquidGlassRefs.isWindowsPlatform ? 0.14 : 0.06;
      if ((currentSeconds - _playheadNotifier.value).abs() >
          playheadDeltaThreshold) {
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
      final boundarySeconds = trimEnd;

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

    _completedSubscription = _player.stream.completed.listen((completed) async {
      if (!completed ||
          !_isPlaybackActive ||
          !_editorController.isAutoLoopEnabled ||
          _isScrubbing ||
          _isLoopBoundaryTransitioning) {
        return;
      }

      final trimStart = _editorController.trimStartSeconds;
      final trimEnd = _editorController.trimEndSeconds;
      final reachedSeconds = _playheadNotifier.value;
      if (trimEnd <= trimStart + EditorController.minTrimLengthSeconds) {
        return;
      }

      if (!_editorController.hasUserEditedTrim &&
          reachedSeconds >= trimStart + EditorController.minTrimLengthSeconds &&
          reachedSeconds <
              trimEnd - EditorController.autoTrimAdjustEpsilonSeconds) {
        final adjustedEnd =
            (reachedSeconds - EditorController.defaultTrimEndOffsetSeconds)
                .clamp(
                  trimStart + EditorController.minTrimLengthSeconds,
                  trimEnd,
                )
                .toDouble();
        _editorController.setAutoDetectedTrimEnd(adjustedEnd);
      }

      if (_editorController.loopMode == LoopMode.pingPong) {
        if (!_isReverseDirection) {
          await _enterReversePhase();
        }
        return;
      }

      await _restartForwardLoop(trimStart);
    });
  }

  Future<void> _handleOpenFromAppBar({required bool fromLibrary}) async {
    if (_editorController.isExporting || _editorController.isFrameExporting) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('書き出し中は入力動画を切り替えできません。'),
          behavior: _snackBarBehavior,
        ),
      );
      return;
    }

    if (fromLibrary) {
      await widget.onRequestOpenFromLibrary();
      return;
    }

    await widget.onRequestOpenFromFiles();
  }

  Future<void> _initialize() async {
    final initializeTimer = Stopwatch()..start();
    unawaited(_loadExportSettings());
    _scheduleDurationProbeFallback();

    _playheadNotifier.value = 0;

    try {
      _beginSlowOpenIndicatorWatch();
      debugPrint(
          '[EditorInit] player.open start: ${initializeTimer.elapsedMilliseconds}ms');
      await _player.open(Media(widget.inputPath));
      debugPrint(
          '[EditorInit] player.open done: ${initializeTimer.elapsedMilliseconds}ms');
      await _player.seek(Duration.zero);
      await _player.play();
      _scheduleThumbnailBuild(force: true);
      debugPrint(
          '[EditorInit] first playback started: ${initializeTimer.elapsedMilliseconds}ms');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('動画の読み込みに失敗しました: $error'),
          behavior: _snackBarBehavior,
        ),
      );
    } finally {
      _endSlowOpenIndicatorWatch();
    }
  }

  void _beginSlowOpenIndicatorWatch() {
    _slowOpenIndicatorTimer?.cancel();
    _slowOpenIndicatorTimer = Timer(_slowOpenIndicatorDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _isSlowOpeningVisible = true);
    });
  }

  void _endSlowOpenIndicatorWatch() {
    _slowOpenIndicatorTimer?.cancel();
    _slowOpenIndicatorTimer = null;
    if (!mounted) {
      _isSlowOpeningVisible = false;
      return;
    }
    if (_isSlowOpeningVisible) {
      setState(() => _isSlowOpeningVisible = false);
    }
  }

  void _scheduleDurationProbeFallback() {
    _durationProbeFallbackTimer?.cancel();
    _durationProbeFallbackTimer = Timer(const Duration(seconds: 2), () async {
      if (_editorController.totalDuration > Duration.zero) {
        return;
      }

      final timer = Stopwatch()..start();
      await _editorController.loadDuration(widget.inputPath);
      debugPrint(
        '[EditorInit] fallback duration probe done: '
        '${timer.elapsedMilliseconds}ms',
      );
    });
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

    _editorController.setLoopCount(
      prefs.getInt(_prefLoopCount) ?? _editorController.loopCount,
    );

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

    _imageExportDirectory = _normalizeDirectory(
      prefs.getString(_prefImageExportDir),
    );
    _videoExportDirectory = _normalizeDirectory(
      prefs.getString(_prefVideoExportDir),
    );
    _gifExportDirectory = _normalizeDirectory(
      prefs.getString(_prefGifExportDir),
    );
    _outputNameTemplate = _normalizeOutputNameTemplate(
      prefs.getString(_prefOutputNameTemplate),
    );
    _saveToPhotoLibrary = prefs.getBool(_prefSaveToPhotoLibrary) ?? true;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistExportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefExportFormat,
      _editorController.exportFormat.name,
    );
    await prefs.setInt(_prefLoopCount, _editorController.loopCount);
    await prefs.setString(
      _prefGifQuality,
      _editorController.gifQualityPreset.name,
    );
    await prefs.setString(_prefGifFps, _editorController.gifFpsPreset.name);
    await prefs.setString(_prefImageExportDir, _imageExportDirectory ?? '');
    await prefs.setString(_prefVideoExportDir, _videoExportDirectory ?? '');
    await prefs.setString(_prefGifExportDir, _gifExportDirectory ?? '');
    await prefs.setString(
      _prefOutputNameTemplate,
      _normalizeOutputNameTemplate(_outputNameTemplate),
    );
    await prefs.setBool(_prefSaveToPhotoLibrary, _saveToPhotoLibrary);
  }

  void _schedulePersistExportSettings() {
    _settingsPersistDebounce?.cancel();
    _settingsPersistDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistExportSettings());
    });
  }

  String _normalizeOutputNameTemplate(String? value) {
    final normalized = _outputFileNamingService.normalizeTemplate(value);
    return normalized;
  }

  String? _normalizeDirectory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
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
        final trimEnd = _editorController.trimEndSeconds;
        final boundary = trimEnd;
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
    final thumbnailTimer = Stopwatch()..start();
    if (mounted && !_isScrubbing) {
      setState(() => _isLoadingThumbnails = true);
    } else {
      _isLoadingThumbnails = true;
    }

    try {
      final runQuickPass = _isMobilePlatform &&
          !_quickThumbnailPhaseCompleted &&
          _thumbnails.isEmpty;
      final thumbnails = await _thumbnailService.buildStrip(
        inputPath: widget.inputPath,
        duration: _editorController.totalDuration,
        zoomLevel: zoom,
        viewportWidth: _timelineViewportWidth,
        tileBaseWidth: _tileBaseWidth,
        targetCountCap: runQuickPass ? _initialMobileThumbnailCount : null,
        cacheVariant: runQuickPass ? 'quick' : 'full',
      );

      if (!mounted || generation != _thumbnailGeneration) {
        return;
      }

      debugPrint(
        '[Thumbnail] loaded ${thumbnails.length} items '
        '(quick=$runQuickPass) in ${thumbnailTimer.elapsedMilliseconds}ms',
      );
      if (thumbnails.isEmpty) {
        debugPrint(
          '[Thumbnail] empty result '
          'duration=${_editorController.totalDuration.inMilliseconds}ms '
          'viewport=${_timelineViewportWidth.toStringAsFixed(1)} '
          'zoom=${zoom.toStringAsFixed(2)} '
          'path=${widget.inputPath}',
        );
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

      if (runQuickPass) {
        _quickThumbnailPhaseCompleted = true;
        _scheduleThumbnailBuild(force: true);
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

        if (next <= trimStart + _reverseStartBoundaryEpsilonSeconds) {
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
      final trimEnd = _editorController.trimEndSeconds;
      final boundary = trimEnd;
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

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
        SnackBar(content: Text(err), behavior: _snackBarBehavior),
      );
      return;
    }

    if (_editorController.isExporting || _editorController.isFrameExporting) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u66F8\u304D\u51FA\u3057\u4E2D\u306F\u52D5\u753B\u3092\u5207\u308A\u66FF\u3048\u3067\u304D\u307E\u305B\u3093\u3002',
          ),
          behavior: _snackBarBehavior,
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

    _lastVideoExportToPhotoLibrary = false;

    final success = await controller.export(
      inputPath: widget.inputPath,
      outputPath: outputPath,
    );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      final exportedPath = controller.lastOutputPath;
      if (isMobilePhotoLibrary && exportedPath != null) {
        final saved = await _storeExportToGallery(
          exportedPath,
          controller.exportFormat.label,
        );
        _lastVideoExportToPhotoLibrary = saved;
        if (mounted) setState(() {});
      } else {
        _lastVideoExportToPhotoLibrary = false;
        if (mounted) setState(() {});
        messenger.showSnackBar(
          SnackBar(
            content: Text('書き出しが完了しました。'),
            behavior: _snackBarBehavior,
          ),
        );
      }
    } else if (controller.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage!),
          behavior: _snackBarBehavior,
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

    _lastFrameExportToPhotoLibrary = false;

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
            behavior: _snackBarBehavior,
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
      final saved = await _storeFrameToGallery(framePath);
      _lastFrameExportToPhotoLibrary = saved;
      if (mounted) setState(() {});
      return;
    }

    _lastFrameExportToPhotoLibrary = false;
    if (mounted) setState(() {});

    messenger.showSnackBar(
      SnackBar(
        content: Text('フレーム画像を書き出しました: $framePath'),
        behavior: _snackBarBehavior,
      ),
    );
  }

  Future<bool> _storeFrameToGallery(String imagePath) async {
    if (!mounted) return false;

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
        throw Exception('保存に失敗しました。');
      }
      messenger.showSnackBar(
        _buildPhotoLibrarySavedSnackBar('フレーム画像をフォトライブラリに保存しました。'),
      );
      return true;
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '\u30D5\u30A9\u30C8\u30E9\u30A4\u30D6\u30E9\u30EA\u4FDD\u5B58\u306B\u5931\u6557\u3057\u307E\u3057\u305F: $error',
          ),
          behavior: _snackBarBehavior,
        ),
      );
      return false;
    }
  }

  Future<bool> _storeExportToGallery(
    String filePath,
    String formatLabel,
  ) async {
    if (!mounted) return false;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final useIosAssetCreation = !kIsWeb && Platform.isIOS;
      final result = await ImageGallerySaver.saveFile(
        filePath,
        name: p.basename(filePath),
        isReturnPathOfIOS: useIosAssetCreation,
      );
      final isSuccess =
          (result['isSuccess'] == true) || (result['success'] == true);
      if (!isSuccess) {
        throw Exception('保存に失敗しました。');
      }
      messenger.showSnackBar(
        _buildPhotoLibrarySavedSnackBar(
          '$formatLabel をフォトライブラリに保存しました。',
        ),
      );
      return true;
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('フォトライブラリ保存に失敗しました: $error'),
          behavior: _snackBarBehavior,
        ),
      );
      return false;
    }
  }

  SnackBar _buildPhotoLibrarySavedSnackBar(String message) {
    return SnackBar(
      behavior: _snackBarBehavior,
      content: Row(
        children: <Widget>[
          Expanded(child: Text(message)),
          IconButton(
            tooltip: '保存先を開く',
            onPressed: () {
              unawaited(_openPhotoLibrary());
            },
            icon: const Icon(Icons.folder_open_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _openLastOutputDestination(EditorController controller) async {
    final outputPath = controller.lastOutputPath;
    if (outputPath == null) {
      return;
    }

    if (_lastVideoExportToPhotoLibrary) {
      await _openPhotoLibrary();
      return;
    }

    await OpenFilex.open(outputPath);
  }

  Future<void> _openLastFrameDestination(EditorController controller) async {
    final framePath = controller.lastFrameOutputPath;
    if (framePath == null) {
      return;
    }

    if (_lastFrameExportToPhotoLibrary) {
      await _openPhotoLibrary();
      return;
    }

    await OpenFilex.open(framePath);
  }

  Future<void> _openPhotoLibrary() async {
    if (!_isMobilePlatform || kIsWeb || !Platform.isIOS) {
      return;
    }

    final photosUri = Uri.parse('photos-redirect://');
    if (!await canLaunchUrl(photosUri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('フォトライブラリアプリを開けませんでした。'),
          behavior: _snackBarBehavior,
        ),
      );
      return;
    }
    await launchUrl(photosUri, mode: LaunchMode.externalApplication);
  }

  Future<String?> _resolveVideoOutputPath(ExportFormat format) async {
    final loopType = _editorController.loopMode == LoopMode.pingPong
        ? 'pingpongLoop'
        : 'loop';

    if (_isMobilePlatform && _saveToPhotoLibrary) {
      final tempDir = await getTemporaryDirectory();
      return _outputFileNamingService.buildOutputPath(
        directoryPath: tempDir.path,
        inputFilePath: widget.inputPath,
        loopType: loopType,
        extension: format.extension,
        template: _normalizeOutputNameTemplate(_outputNameTemplate),
      );
    }

    final directory = format == ExportFormat.gif
        ? _gifExportDirectory
        : _videoExportDirectory;
    if (directory == null || directory.trim().isEmpty) {
      _showPathRequiredMessage();
      return null;
    }
    return _outputFileNamingService.buildOutputPath(
      directoryPath: directory,
      inputFilePath: widget.inputPath,
      loopType: loopType,
      extension: format.extension,
      template: _normalizeOutputNameTemplate(_outputNameTemplate),
    );
  }

  Future<String?> _resolveFrameOutputPath() async {
    if (_isMobilePlatform && _saveToPhotoLibrary) {
      final tempDir = await getTemporaryDirectory();
      return _outputFileNamingService.buildOutputPath(
        directoryPath: tempDir.path,
        inputFilePath: widget.inputPath,
        loopType: 'snapshot',
        extension: 'jpg',
        template: _normalizeOutputNameTemplate(_outputNameTemplate),
      );
    }

    final directory = _imageExportDirectory;
    if (directory == null || directory.trim().isEmpty) {
      _showPathRequiredMessage();
      return null;
    }
    return _outputFileNamingService.buildOutputPath(
      directoryPath: directory,
      inputFilePath: widget.inputPath,
      loopType: 'snapshot',
      extension: 'jpg',
      template: _normalizeOutputNameTemplate(_outputNameTemplate),
    );
  }

  void _showPathRequiredMessage() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('書き出し先パスを設定してください。'),
        behavior: _snackBarBehavior,
      ),
    );
  }

  Future<String?> _selectDirectory(String dialogTitle) async {
    final selected = widget.pickDirectoryOverride != null
        ? await widget.pickDirectoryOverride!.call(dialogTitle)
        : await FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle);
    if (selected == null || selected.trim().isEmpty) {
      return null;
    }
    return selected.trim();
  }

  @override
  void dispose() {
    _thumbnailDebounce?.cancel();
    _scrubSeekTimer?.cancel();
    _settingsPersistDebounce?.cancel();
    _durationProbeFallbackTimer?.cancel();
    _slowOpenIndicatorTimer?.cancel();
    _stopReverseTicker();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completedSubscription?.cancel();
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
          final transportOverlay = PlaybackTransportBar(
            isPlaying: _isPlaybackActive,
            isDisabled: controller.isExporting ||
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
          );
          final controlsPanel = _buildControlPanel(context, controller);
          final shell = ValueListenableBuilder<double>(
            valueListenable: _playheadNotifier,
            builder: (context, playheadSeconds, _) {
              final playheadDuration = Duration(
                milliseconds: (playheadSeconds * 1000).round(),
              );

              final content = EditorShell(
                title: p.basename(widget.inputPath),
                onImportDefaultRequested: () {
                  unawaited(
                    _handleOpenFromAppBar(fromLibrary: _isMobilePlatform),
                  );
                },
                onImportFromFilesRequested: () {
                  unawaited(_handleOpenFromAppBar(fromLibrary: false));
                },
                onImportFromLibraryRequested: () {
                  unawaited(_handleOpenFromAppBar(fromLibrary: true));
                },
                showDropHighlight: _isDraggingReplace,
                preview: PreviewStage(
                  video: Video(
                    controller: _videoController,
                    controls: NoVideoControls,
                  ),
                  positionLabel: _formatDuration(playheadDuration),
                  isPingPong: controller.loopMode == LoopMode.pingPong,
                  isReverseDirection: _isReverseDirection,
                  centerOverlay: _isSlowOpeningVisible
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('iCloud から動画を読み込み中...'),
                              ],
                            ),
                          ),
                        )
                      : null,
                  bottomOverlay: transportOverlay,
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
                        totalDuration: controller.hasUserEditedTrim
                            ? controller.totalDuration
                            : Duration(
                                milliseconds:
                                    (controller.trimEndSeconds * 1000).round(),
                              ),
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
                        onScrubStart:
                            controller.isExporting ? null : _handleScrubStart,
                        onScrubUpdate:
                            controller.isExporting ? null : _handleScrubUpdate,
                        onScrubEnd: controller.isExporting
                            ? null
                            : (seconds) {
                                unawaited(_handleScrubEnd(seconds));
                              },
                        onPinchZoomChanged: controller.isExporting
                            ? null
                            : (zoomLevel) {
                                controller.setZoomLevel(zoomLevel);
                                _scheduleThumbnailBuild(force: false);
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
                    if (_isMobilePlatform)
                      Text(
                        'タイムライン: 2本指ピンチで拡大縮小 / 2本指スライドで左右スクロール',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      TimelineZoomBar(
                        zoomLevel: controller.zoomLevel,
                        onChanged: controller.isExporting
                            ? null
                            : (value) => controller.setZoomLevel(value),
                      ),
                  ],
                ),
                controls: controlsPanel,
              );

              return content;
            },
          );
          if (!_supportsDesktopDrop) {
            return shell;
          }
          return DropTarget(
            onDragEntered: (_) => setState(() => _isDraggingReplace = true),
            onDragExited: (_) => setState(() => _isDraggingReplace = false),
            onDragDone: (details) async {
              setState(() => _isDraggingReplace = false);
              if (details.files.isEmpty) {
                return;
              }
              await _handleDropReplace(details.files.first.path);
            },
            child: shell,
          );
        },
      ),
    );
  }

  Future<void> _showExportSettingsModal(EditorController controller) async {
    final imagePathController = TextEditingController(
      text: _imageExportDirectory ?? '',
    );
    final videoPathController = TextEditingController(
      text: _videoExportDirectory ?? '',
    );
    final gifPathController = TextEditingController(
      text: _gifExportDirectory ?? '',
    );
    final templateController = TextEditingController(text: _outputNameTemplate);

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final baseBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: LiquidGlassRefs.outlineSoft),
          );

          return Theme(
            data: theme.copyWith(
              dividerColor: LiquidGlassRefs.outlineSoft,
              iconTheme: theme.iconTheme
                  .copyWith(color: LiquidGlassRefs.textSecondary),
              inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                filled: true,
                fillColor: LiquidGlassRefs.surfaceDeep.withValues(alpha: 0.52),
                labelStyle:
                    const TextStyle(color: LiquidGlassRefs.textSecondary),
                hintStyle: TextStyle(
                  color: LiquidGlassRefs.textSecondary.withValues(alpha: 0.75),
                ),
                border: baseBorder,
                enabledBorder: baseBorder,
                focusedBorder: baseBorder.copyWith(
                  borderSide: const BorderSide(
                    color: LiquidGlassRefs.accentBlue,
                    width: 1.4,
                  ),
                ),
                disabledBorder: baseBorder.copyWith(
                  borderSide: BorderSide(
                    color: LiquidGlassRefs.outlineSoft.withValues(alpha: 0.55),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: LiquidGlassRefs.accentBlue,
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LiquidGlassRefs.accentBlue,
                  backgroundColor:
                      LiquidGlassRefs.surfaceDeep.withValues(alpha: 0.46),
                  side: const BorderSide(color: LiquidGlassRefs.outlineSoft),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: LiquidGlassRefs.accentBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return AlertDialog(
                  backgroundColor:
                      LiquidGlassRefs.surfaceDeep.withValues(alpha: 0.96),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: const BorderSide(color: LiquidGlassRefs.outlineSoft),
                  ),
                  titleTextStyle:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: LiquidGlassRefs.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                  contentTextStyle:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: LiquidGlassRefs.textPrimary,
                          ),
                  title: const Text('書き出し設定'),
                  content: SizedBox(
                    width: 540,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          DropdownButtonFormField<ExportFormat>(
                            initialValue: controller.exportFormat,
                            decoration: const InputDecoration(
                              labelText: '書き出し形式',
                            ),
                            items: ExportFormat.values
                                .map(
                                  (format) => DropdownMenuItem<ExportFormat>(
                                    value: format,
                                    child: Text(format.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              controller.setExportFormat(value);
                              _schedulePersistExportSettings();
                              setModalState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 12),
                          if (controller.exportFormat ==
                              ExportFormat.mp4) ...<Widget>[
                            const Text('ループ回数'),
                            Slider(
                              value: controller.loopCount.toDouble(),
                              min: 1,
                              max: 20,
                              divisions: 19,
                              label: '${controller.loopCount}',
                              onChanged: (value) {
                                controller.setLoopCount(value.round());
                                _schedulePersistExportSettings();
                                setModalState(() {});
                                if (mounted) setState(() {});
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('${controller.loopCount}回'),
                            ),
                          ],
                          const Divider(height: 24),
                          DropdownButtonFormField<GifQualityPreset>(
                            initialValue: controller.gifQualityPreset,
                            decoration:
                                const InputDecoration(labelText: 'GIF品質'),
                            items: GifQualityPreset.values
                                .map(
                                  (preset) =>
                                      DropdownMenuItem<GifQualityPreset>(
                                    value: preset,
                                    child: Text(preset.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              controller.setGifQualityPreset(value);
                              _schedulePersistExportSettings();
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<GifFpsPreset>(
                            initialValue: controller.gifFpsPreset,
                            decoration: const InputDecoration(
                              labelText: 'GIF FPS',
                            ),
                            items: GifFpsPreset.values
                                .map(
                                  (preset) => DropdownMenuItem<GifFpsPreset>(
                                    value: preset,
                                    child: Text(preset.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              controller.setGifFpsPreset(value);
                              _schedulePersistExportSettings();
                              setModalState(() {});
                            },
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            key: const Key('output-name-template-field'),
                            controller: templateController,
                            decoration: const InputDecoration(
                              labelText: '書き出しファイル名テンプレート（拡張子なし）',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _outputNameTemplate = value;
                              _schedulePersistExportSettings();
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '使用できる変数: {looptype}, {filename}\n'
                            '例: {looptype}_{filename}\n'
                            '出力例: loop_sample.mp4 / pingpongLoop_sample.gif / snapshot_sample.jpg',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Divider(height: 24),
                          _buildPathSettingRow(
                            fieldKey: const Key('image-export-path-field'),
                            label: '画像書き出しパス',
                            controller: imagePathController,
                            enabled:
                                !(_isMobilePlatform && _saveToPhotoLibrary),
                            onChanged: (value) {
                              _imageExportDirectory =
                                  _normalizeDirectory(value);
                              _schedulePersistExportSettings();
                            },
                            onPick: () async {
                              final selected = await _selectDirectory(
                                '画像書き出しフォルダを選択',
                              );
                              if (selected == null) {
                                return;
                              }
                              imagePathController.text = selected;
                              _imageExportDirectory = selected;
                              _schedulePersistExportSettings();
                              setModalState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildPathSettingRow(
                            fieldKey: const Key('video-export-path-field'),
                            label: '動画書き出しパス',
                            controller: videoPathController,
                            enabled:
                                !(_isMobilePlatform && _saveToPhotoLibrary),
                            onChanged: (value) {
                              _videoExportDirectory =
                                  _normalizeDirectory(value);
                              _schedulePersistExportSettings();
                            },
                            onPick: () async {
                              final selected = await _selectDirectory(
                                '動画書き出しフォルダを選択',
                              );
                              if (selected == null) {
                                return;
                              }
                              videoPathController.text = selected;
                              _videoExportDirectory = selected;
                              _schedulePersistExportSettings();
                              setModalState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildPathSettingRow(
                            fieldKey: const Key('gif-export-path-field'),
                            label: 'GIF書き出しパス',
                            controller: gifPathController,
                            enabled:
                                !(_isMobilePlatform && _saveToPhotoLibrary),
                            onChanged: (value) {
                              _gifExportDirectory = _normalizeDirectory(value);
                              _schedulePersistExportSettings();
                            },
                            onPick: () async {
                              final selected = await _selectDirectory(
                                'GIF書き出しフォルダを選択',
                              );
                              if (selected == null) {
                                return;
                              }
                              gifPathController.text = selected;
                              _gifExportDirectory = selected;
                              _schedulePersistExportSettings();
                              setModalState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                          if (_isMobilePlatform) ...<Widget>[
                            const Divider(height: 24),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('フォトライブラリに直接保存'),
                              value: _saveToPhotoLibrary,
                              onChanged: (value) {
                                _saveToPhotoLibrary = value;
                                _schedulePersistExportSettings();
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
            ),
          );
        },
      );
    } finally {
      imagePathController.dispose();
      videoPathController.dispose();
      gifPathController.dispose();
      templateController.dispose();
    }
  }

  Widget _buildPathSettingRow({
    Key? fieldKey,
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required ValueChanged<String> onChanged,
    required Future<void> Function() onPick,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              hintText: enabled ? '書き出し先パスを入力' : 'フォトライブラリ保存時は不要',
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: enabled ? () => unawaited(onPick()) : null,
          child: const Text('選択'),
        ),
      ],
    );
  }

  Widget _buildControlPanel(BuildContext context, EditorController controller) {
    final exportActionDisabled = controller.isExporting ||
        controller.isFrameExporting ||
        controller.totalDuration <= Duration.zero;
    final isMobile = _isMobilePlatform;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          runSpacing: 8,
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            LoopModeGlassTabs(
              width: isMobile
                  ? LiquidGlassRefs.loopTabsMobileWidth
                  : LiquidGlassRefs.loopTabsDesktopWidth,
              loopMode: controller.loopMode,
              isAutoLoopEnabled: controller.isAutoLoopEnabled,
              enabled: !exportActionDisabled,
              onLoopModeChanged: controller.setLoopMode,
              onAutoLoopChanged: controller.setAutoLoopEnabled,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: LiquidGlassActionButton.icon(
                fillColor: LiquidGlassRefs.accentOrange.withValues(alpha: 0.5),
                foregroundColor: LiquidGlassRefs.textPrimary,
                borderColor: const Color.fromARGB(102, 0, 0, 0),
                style: isMobile
                    ? const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    : null,
                onPressed: exportActionDisabled
                    ? null
                    : () => _exportCurrentFrame(controller),
                icon: const Icon(Icons.image_rounded),
                label: Text(
                  isMobile ? 'フレーム書き出し' : 'このフレームを画像書き出し',
                ),
              ),
            ),
            const SizedBox(width: LiquidGlassRefs.exportButtonGap),
            Expanded(
              child: LiquidGlassActionButton.icon(
                primary: true,
                fillColor: LiquidGlassRefs.accentOrange,
                foregroundColor: Colors.white,
                borderColor: const Color(0x66CFE9FF),
                style: isMobile
                    ? const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    : null,
                onPressed: exportActionDisabled
                    ? null
                    : () => _startExport(controller),
                icon: const Icon(Icons.movie_creation_rounded),
                label: const Text('書き出し'),
              ),
            ),
            const SizedBox(width: LiquidGlassRefs.exportButtonGap),
            InteractiveLiquidGlassIconButton(
              buttonKey: const Key('export-settings-button'),
              icon: Icons.settings,
              tooltip: '書き出し設定',
              isDisabled: exportActionDisabled,
              onPressed: () => _showExportSettingsModal(controller),
              useLiquidGlass: LiquidGlassRefs.supportsLiquidGlass,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: LiquidGlassRefs.textSecondary,
            ),
          ],
        ),
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
                ? 'フレーム画像を書き出し中...'
                : '${(controller.exportProgress * 100).toStringAsFixed(0)}% ${controller.exportMessage}',
          ),
        ],
        if (controller.lastOutputPath != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _lastVideoExportToPhotoLibrary
                ? '出力先: フォトライブラリ'
                : '出力先: ${controller.lastOutputPath}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                unawaited(_openLastOutputDestination(controller));
              },
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('保存先を開く'),
            ),
          ),
        ],
        if (controller.lastFrameOutputPath != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _lastFrameExportToPhotoLibrary
                ? '画像出力先: フォトライブラリ'
                : '画像出力先: ${controller.lastFrameOutputPath}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                unawaited(_openLastFrameDestination(controller));
              },
              icon: const Icon(Icons.image_search_rounded),
              label: const Text('保存先を開く'),
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
