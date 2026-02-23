import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/export_format.dart';
import '../../models/loop_mode.dart';
import '../../models/timeline_thumbnail.dart';
import '../../services/ffmpeg_cli_video_processor.dart';
import '../../services/file_import_service.dart';
import '../../services/timeline_thumbnail_service.dart';
import '../../state/editor_controller.dart';
import '../widgets/editor_shell.dart';
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

  bool _isPlaybackActive = true;
  bool _isReverseDirection = false;
  bool _isSeekingByReverseTicker = false;
  bool _isLoadingThumbnails = false;
  bool _isDraggingReplace = false;
  bool _isScrubbing = false;

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

  List<TimelineThumbnail> _thumbnails = const <TimelineThumbnail>[];

  bool get _supportsDesktopDrop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
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

      if (_editorController.loopMode == LoopMode.pingPong) {
        if (!_isReverseDirection && currentSeconds >= trimEnd) {
          _isReverseDirection = true;
          if (mounted) {
            setState(() {});
          }
          await _player.pause();
          _startReverseTicker();
        }
        return;
      }

      if (currentSeconds >= trimEnd) {
        await _player.seek(Duration(milliseconds: (trimStart * 1000).round()));
        _playheadNotifier.value = trimStart;
        if (_isPlaybackActive) {
          await _player.play();
        }
      }
    });
  }

  Future<void> _initialize() async {
    await _editorController.loadDuration(widget.inputPath);
    try {
      await _player.open(Media(widget.inputPath));
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
        if (mounted) {
          setState(() {});
        }
      }
    }

    _scheduleThumbnailBuild(force: false);
  }

  void _scheduleThumbnailBuild({required bool force}) {
    _thumbnailDebounce?.cancel();
    _thumbnailDebounce = Timer(
      force ? Duration.zero : const Duration(milliseconds: 260),
      () => _buildThumbnails(force: force),
    );
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
    if (!mounted) {
      return;
    }
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

  void _startReverseTicker() {
    if (_reverseTicker != null) {
      return;
    }

    _reverseTicker = Timer.periodic(const Duration(milliseconds: 40), (
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
        final next = (current - 0.04).clamp(trimStart, trimEnd).toDouble();

        _isSeekingByReverseTicker = true;
        await _player.seek(Duration(milliseconds: (next * 1000).round()));
        _playheadNotifier.value = next;
        _isSeekingByReverseTicker = false;

        if (next <= trimStart + 0.0001) {
          _isReverseDirection = false;
          _stopReverseTicker();
          if (_isPlaybackActive) {
            await _player.play();
          }
          if (mounted) {
            setState(() {});
          }
        }
      } finally {
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
      if (_editorController.loopMode == LoopMode.pingPong &&
          _isReverseDirection) {
        await _player.pause();
        _startReverseTicker();
      } else {
        await _player.play();
      }
    }
    if (mounted) {
      setState(() {});
    }
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
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _seekTo(double seconds) async {
    final target = _clampToDuration(seconds);
    _stopReverseTicker();
    _isReverseDirection = false;

    _editorController.seekTo(target);
    _playheadNotifier.value = target;
    await _player.seek(Duration(milliseconds: (target * 1000).round()));

    if (_isPlaybackActive) {
      await _player.play();
    }
    if (mounted) {
      setState(() {});
    }
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

    if (_editorController.isExporting) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('書き出し中は動画を切り替えできません。'),
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
    final outputPath = await _selectOutputPath(controller.exportFormat);
    if (outputPath == null) return;

    final success = await controller.export(
      inputPath: widget.inputPath,
      outputPath: outputPath,
    );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('書き出しが完了しました。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (controller.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _selectOutputPath(ExportFormat format) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp('[:.]'),
      '-',
    );
    final suggestedName = 'loop_$timestamp.${format.extension}';

    try {
      final selected = await FilePicker.platform.saveFile(
        dialogTitle: '書き出し先を選択',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: <String>[format.extension],
      );
      if (selected != null && selected.isNotEmpty) {
        return selected;
      }
    } catch (_) {
      // saveFile未対応の環境ではDocumentsにフォールバック。
    }

    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, suggestedName);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final seconds = totalSeconds % 60;
    final minutes = (totalSeconds ~/ 60) % 60;
    final hours = totalSeconds ~/ 3600;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
                  video: Video(controller: _videoController),
                  isPlaying: _isPlaybackActive,
                  onPlayPause: _togglePlayPause,
                  positionLabel:
                      '${_formatDuration(playheadDuration)}  ($trimSummary)',
                  isPingPong: controller.loopMode == LoopMode.pingPong,
                  isReverseDirection: _isReverseDirection,
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
                        onTrimChanged: (start, end) async {
                          controller.setTrimRange(
                            startSeconds: start,
                            endSeconds: end,
                          );
                          if (playheadSeconds < start ||
                              playheadSeconds > end) {
                            await _seekTo(start);
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

  Widget _buildControlPanel(BuildContext context, EditorController controller) {
    final iosUnsupported = defaultTargetPlatform == TargetPlatform.iOS;

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
              onSelectionChanged: controller.isExporting
                  ? null
                  : (selection) => controller.setLoopMode(selection.first),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('回数'),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: controller.loopCount.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '${controller.loopCount}',
                    onChanged: controller.isExporting
                        ? null
                        : (value) => controller.setLoopCount(value.round()),
                  ),
                ),
                Text('${controller.loopCount}'),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('範囲ループ'),
                Switch(
                  value: controller.isAutoLoopEnabled,
                  onChanged: controller.isExporting
                      ? null
                      : controller.setAutoLoopEnabled,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          runSpacing: 8,
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<ExportFormat>(
                initialValue: controller.exportFormat,
                decoration: const InputDecoration(
                  labelText: '書き出し形式',
                  border: OutlineInputBorder(),
                ),
                items: ExportFormat.values
                    .map(
                      (format) => DropdownMenuItem<ExportFormat>(
                        value: format,
                        child: Text(format.label),
                      ),
                    )
                    .toList(),
                onChanged: controller.isExporting
                    ? null
                    : (value) {
                        if (value != null) {
                          controller.setExportFormat(value);
                        }
                      },
              ),
            ),
            FilledButton.icon(
              onPressed:
                  controller.isExporting ||
                      controller.exportFormat == ExportFormat.gif ||
                      iosUnsupported
                  ? null
                  : () => _startExport(controller),
              icon: const Icon(Icons.movie_creation_rounded),
              label: const Text('書き出し'),
            ),
            if (controller.exportFormat == ExportFormat.gif)
              Text(
                'GIFはPhase 2で実装予定です',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (iosUnsupported)
              Text(
                'iOSではFFmpeg CLI未対応のため、書き出しは現状無効です。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        if (controller.isExporting ||
            controller.exportProgress > 0) ...<Widget>[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: controller.exportProgress == 0
                ? null
                : controller.exportProgress,
          ),
          const SizedBox(height: 6),
          Text(
            '${(controller.exportProgress * 100).toStringAsFixed(0)}% ${controller.exportMessage}',
          ),
        ],
        if (controller.lastOutputPath != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '出力先: ${controller.lastOutputPath}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => OpenFilex.open(controller.lastOutputPath!),
              icon: const Icon(Icons.folder_open_rounded),
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
