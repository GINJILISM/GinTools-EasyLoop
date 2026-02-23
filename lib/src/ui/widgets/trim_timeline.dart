import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/timeline_thumbnail.dart';

class TrimTimeline extends StatefulWidget {
  const TrimTimeline({
    super.key,
    required this.totalDuration,
    required this.trimStartSeconds,
    required this.trimEndSeconds,
    required this.playheadSeconds,
    required this.zoomLevel,
    required this.thumbnails,
    required this.onTrimChanged,
    required this.onSeek,
    this.onScrubStart,
    this.onScrubUpdate,
    this.onScrubEnd,
    this.onViewportWidthChanged,
    this.tileBaseWidth = 96,
  });

  final Duration totalDuration;
  final double trimStartSeconds;
  final double trimEndSeconds;
  final double playheadSeconds;
  final double zoomLevel;
  final List<TimelineThumbnail> thumbnails;
  final void Function(double startSeconds, double endSeconds) onTrimChanged;
  final ValueChanged<double> onSeek;
  final VoidCallback? onScrubStart;
  final ValueChanged<double>? onScrubUpdate;
  final ValueChanged<double>? onScrubEnd;
  final ValueChanged<double>? onViewportWidthChanged;
  final double tileBaseWidth;

  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

class _TrimTimelineState extends State<TrimTimeline> {
  final ScrollController _scrollController = ScrollController();
  double _lastViewportWidth = -1;
  bool _isScrubbingPlayhead = false;
  bool _isDraggingHandle = false;
  double _lastScrubSeconds = 0;

  double get _totalSeconds =>
      math.max(0.1, widget.totalDuration.inMilliseconds / 1000);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        if ((viewportWidth - _lastViewportWidth).abs() > 1.0) {
          _lastViewportWidth = viewportWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onViewportWidthChanged?.call(viewportWidth);
          });
        }

        final fitPps = viewportWidth / _totalSeconds;
        final effectivePps = fitPps * widget.zoomLevel;
        final timelineWidth = math.max(
          viewportWidth,
          _totalSeconds * effectivePps,
        );

        final trimStartPx = _secondsToPx(widget.trimStartSeconds, effectivePps);
        final trimEndPx = _secondsToPx(widget.trimEndSeconds, effectivePps);
        final playheadPx = _secondsToPx(widget.playheadSeconds, effectivePps);
        final markerStep = _resolveMarkerStep(effectivePps);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E2438),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: timelineWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        widget.onSeek(
                          _pxToSeconds(details.localPosition.dx, effectivePps),
                        );
                      },
                      onHorizontalDragStart: (details) {
                        if (_isDraggingHandle || widget.onScrubUpdate == null) {
                          return;
                        }
                        final pointerX = details.localPosition.dx;
                        final isNearHandle =
                            (pointerX - trimStartPx).abs() <= 14 ||
                            (pointerX - trimEndPx).abs() <= 14;
                        if (isNearHandle) {
                          return;
                        }

                        _isScrubbingPlayhead = true;
                        _lastScrubSeconds = _pxToSeconds(
                          pointerX,
                          effectivePps,
                        );
                        widget.onScrubStart?.call();
                        widget.onScrubUpdate?.call(_lastScrubSeconds);
                      },
                      onHorizontalDragUpdate: (details) {
                        if (!_isScrubbingPlayhead) {
                          return;
                        }
                        _lastScrubSeconds = _pxToSeconds(
                          details.localPosition.dx,
                          effectivePps,
                        );
                        widget.onScrubUpdate?.call(_lastScrubSeconds);
                      },
                      onHorizontalDragCancel: () {
                        if (!_isScrubbingPlayhead) {
                          return;
                        }
                        _isScrubbingPlayhead = false;
                        widget.onScrubEnd?.call(_lastScrubSeconds);
                      },
                      onHorizontalDragEnd: (_) {
                        if (!_isScrubbingPlayhead) {
                          return;
                        }
                        _isScrubbingPlayhead = false;
                        widget.onScrubEnd?.call(_lastScrubSeconds);
                      },
                      child: Stack(
                        key: const Key('trim-timeline-surface'),
                        children: <Widget>[
                          _buildThumbnailStrip(timelineWidth),
                          _buildMarkers(
                            timelineWidth,
                            markerStep,
                            effectivePps,
                          ),
                          Positioned(
                            left: 0,
                            right: timelineWidth - trimStartPx,
                            top: 0,
                            bottom: 0,
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.40),
                            ),
                          ),
                          Positioned(
                            left: trimEndPx,
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.40),
                            ),
                          ),
                          Positioned(
                            left: playheadPx,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          _buildTrimHandle(
                            key: const Key('trim-handle-start'),
                            x: trimStartPx,
                            color: colorScheme.tertiary,
                            onDragStart: () {
                              _isDraggingHandle = true;
                            },
                            onDrag: (deltaPx) {
                              final nextStart = _pxToSeconds(
                                trimStartPx + deltaPx,
                                effectivePps,
                              ).clamp(0.0, widget.trimEndSeconds - 0.1);
                              widget.onTrimChanged(
                                nextStart,
                                widget.trimEndSeconds,
                              );
                            },
                            onDragEnd: () {
                              _isDraggingHandle = false;
                            },
                          ),
                          _buildTrimHandle(
                            key: const Key('trim-handle-end'),
                            x: trimEndPx,
                            color: colorScheme.secondary,
                            onDragStart: () {
                              _isDraggingHandle = true;
                            },
                            onDrag: (deltaPx) {
                              final nextEnd =
                                  _pxToSeconds(
                                    trimEndPx + deltaPx,
                                    effectivePps,
                                  ).clamp(
                                    widget.trimStartSeconds + 0.1,
                                    _totalSeconds,
                                  );
                              widget.onTrimChanged(
                                widget.trimStartSeconds,
                                nextEnd,
                              );
                            },
                            onDragEnd: () {
                              _isDraggingHandle = false;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'start ${widget.trimStartSeconds.toStringAsFixed(2)}s  /  end ${widget.trimEndSeconds.toStringAsFixed(2)}s',
            ),
          ],
        );
      },
    );
  }

  Widget _buildThumbnailStrip(double timelineWidth) {
    if (widget.thumbnails.isEmpty) {
      return const Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0x22162A3C)),
            child: Center(
              child: Text(
                'サムネイル生成中...',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    }

    final tileWidth = timelineWidth / widget.thumbnails.length;
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: widget.thumbnails.map((thumbnail) {
            return SizedBox(
              width: tileWidth,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black12),
                child: Center(
                  child: Image.file(
                    File(thumbnail.path),
                    key: ValueKey<String>(thumbnail.path),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: Color(0xFF24374B)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMarkers(double timelineWidth, double markerStep, double pps) {
    final markers = <Widget>[];
    for (double second = 0; second <= _totalSeconds; second += markerStep) {
      final x = _secondsToPx(second, pps);
      markers.add(
        Positioned(
          left: x,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
      );
      markers.add(
        Positioned(
          left: x + 3,
          bottom: 4,
          child: Text(
            '${second.toStringAsFixed(second % 1 == 0 ? 0 : 1)}s',
            style: const TextStyle(fontSize: 10),
          ),
        ),
      );
    }
    return SizedBox(
      width: timelineWidth,
      child: Stack(children: markers),
    );
  }

  Widget _buildTrimHandle({
    required Key key,
    required double x,
    required Color color,
    VoidCallback? onDragStart,
    required ValueChanged<double> onDrag,
    VoidCallback? onDragEnd,
  }) {
    return Positioned(
      left: x - 8,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => onDragStart?.call(),
          onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
          onHorizontalDragCancel: () => onDragEnd?.call(),
          onHorizontalDragEnd: (_) => onDragEnd?.call(),
          child: SizedBox(
            width: 16,
            child: Center(
              child: Container(
                width: 4,
                height: 86,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _secondsToPx(double seconds, double pps) => seconds * pps;

  double _pxToSeconds(double px, double pps) =>
      (px / pps).clamp(0.0, _totalSeconds);

  double _resolveMarkerStep(double pps) {
    if (pps >= 260) return 0.25;
    if (pps >= 170) return 0.5;
    if (pps >= 90) return 1;
    if (pps >= 50) return 2;
    return 5;
  }
}
