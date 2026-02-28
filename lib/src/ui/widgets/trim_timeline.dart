import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/timeline_thumbnail.dart';
import '../liquid_glass/liquid_glass_refs.dart';

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
    this.onPinchZoomChanged,
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
  final ValueChanged<double>? onPinchZoomChanged;
  final double tileBaseWidth;

  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

class _TrimTimelineState extends State<TrimTimeline> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _activeTouchPointers = <int>{};

  double _lastViewportWidth = -1;

  bool _isScrubbingPlayhead = false;
  bool _isDraggingHandle = false;
  double _lastScrubSeconds = 0;

  bool _isMiddlePanning = false;
  Offset? _lastMiddlePanGlobal;
  bool _isTwoFingerGestureActive = false;
  double _pinchStartZoom = 1.0;

  bool _isTouchPanCandidate = false;
  bool _isTouchPanning = false;
  int? _touchPanPointer;
  Offset? _lastTouchPanGlobal;
  Offset? _lastTapUpPosition;
  DateTime? _lastTapUpTime;
  Timer? _doubleTapHoldTimer;
  Widget? _cachedThumbnailStrip;
  int _cachedThumbnailSignature = 0;
  double _cachedThumbnailTimelineWidth = -1;

  double get _totalSeconds =>
      math.max(0.1, widget.totalDuration.inMilliseconds / 1000);

  @override
  void dispose() {
    _doubleTapHoldTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  color: LiquidGlassRefs.timelineSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Listener(
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  onPointerSignal: _handlePointerSignal,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: timelineWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          if (_isMiddlePanning ||
                              _isTwoFingerGestureActive ||
                              _isTouchPanning ||
                              _isTouchPanCandidate) {
                            return;
                          }
                          widget.onSeek(
                            _pxToSeconds(
                              details.localPosition.dx,
                              effectivePps,
                            ),
                          );
                        },
                        onHorizontalDragStart: (details) {
                          if (_isMiddlePanning ||
                              _isTwoFingerGestureActive ||
                              _isTouchPanning ||
                              _isTouchPanCandidate ||
                              _isDraggingHandle ||
                              widget.onScrubUpdate == null) {
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
                        onScaleStart: (details) {
                          if (_activeTouchPointers.length < 2) {
                            return;
                          }
                          _isTwoFingerGestureActive = true;
                          _pinchStartZoom = widget.zoomLevel;
                        },
                        onScaleUpdate: (details) {
                          if (!_isTwoFingerGestureActive ||
                              _activeTouchPointers.length < 2) {
                            return;
                          }

                          final scale = details.scale;
                          if (widget.onPinchZoomChanged != null &&
                              scale.isFinite &&
                              scale > 0) {
                            final nextZoom = (_pinchStartZoom * scale).clamp(
                              0.5,
                              5.0,
                            );
                            if ((nextZoom - widget.zoomLevel).abs() > 0.01) {
                              widget.onPinchZoomChanged?.call(nextZoom);
                            }
                          }

                          final slideDx = details.focalPointDelta.dx;
                          if (slideDx.abs() > 0.01) {
                            _scrollBy(slideDx);
                          }
                        },
                        onScaleEnd: (_) {
                          _isTwoFingerGestureActive = false;
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
                                color: LiquidGlassRefs.accentOrange,
                              ),
                            ),
                            _buildTrimHandle(
                              key: const Key('trim-handle-start'),
                              x: trimStartPx,
                              color: LiquidGlassRefs.accentOrange,
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
                              color: LiquidGlassRefs.accentOrange,
                              onDragStart: () {
                                _isDraggingHandle = true;
                              },
                              onDrag: (deltaPx) {
                                final nextEnd = _pxToSeconds(
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
            ),
          ],
        );
      },
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      _activeTouchPointers.add(event.pointer);
    }

    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kMiddleMouseButton) != 0) {
      _isMiddlePanning = true;
      _lastMiddlePanGlobal = event.position;
      return;
    }

    if (event.kind != PointerDeviceKind.touch) {
      return;
    }

    final now = DateTime.now();
    final isDoubleTap = _lastTapUpTime != null &&
        now.difference(_lastTapUpTime!).inMilliseconds <= 320 &&
        _lastTapUpPosition != null &&
        (event.position - _lastTapUpPosition!).distance <= 24;

    if (isDoubleTap) {
      _isTouchPanCandidate = true;
      _touchPanPointer = event.pointer;
      _lastTouchPanGlobal = event.position;
      _doubleTapHoldTimer?.cancel();
      _doubleTapHoldTimer = Timer(const Duration(milliseconds: 220), () {
        if (_isTouchPanCandidate && _touchPanPointer == event.pointer) {
          _isTouchPanning = true;
        }
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isMiddlePanning && _lastMiddlePanGlobal != null) {
      final dx = event.position.dx - _lastMiddlePanGlobal!.dx;
      _lastMiddlePanGlobal = event.position;
      _scrollBy(dx);
      return;
    }

    if (_isTouchPanning &&
        _touchPanPointer == event.pointer &&
        _lastTouchPanGlobal != null) {
      final dx = event.position.dx - _lastTouchPanGlobal!.dx;
      _lastTouchPanGlobal = event.position;
      _scrollBy(dx);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      _activeTouchPointers.remove(event.pointer);
      if (_activeTouchPointers.length < 2) {
        _isTwoFingerGestureActive = false;
      }
    }

    if (event.kind == PointerDeviceKind.mouse) {
      _isMiddlePanning = false;
      _lastMiddlePanGlobal = null;
      return;
    }

    if (event.kind != PointerDeviceKind.touch ||
        _touchPanPointer != event.pointer) {
      return;
    }

    if (!_isTouchPanning) {
      _lastTapUpTime = DateTime.now();
      _lastTapUpPosition = event.position;
    }

    _clearTouchPanState();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      _activeTouchPointers.remove(event.pointer);
      if (_activeTouchPointers.length < 2) {
        _isTwoFingerGestureActive = false;
      }
    }

    if (event.kind == PointerDeviceKind.mouse) {
      _isMiddlePanning = false;
      _lastMiddlePanGlobal = null;
      return;
    }
    if (event.kind == PointerDeviceKind.touch &&
        _touchPanPointer == event.pointer) {
      _clearTouchPanState();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final rawDelta = event.scrollDelta.dx.abs() > 0.01
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (rawDelta.abs() < 0.01) {
      return;
    }

    _scrollBy(-rawDelta);
  }

  void _clearTouchPanState() {
    _doubleTapHoldTimer?.cancel();
    _doubleTapHoldTimer = null;
    _isTouchPanCandidate = false;
    _isTouchPanning = false;
    _touchPanPointer = null;
    _lastTouchPanGlobal = null;
  }

  void _scrollBy(double dragDeltaX) {
    if (!_scrollController.hasClients) {
      return;
    }

    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) {
      return;
    }

    final nextOffset = (_scrollController.offset - dragDeltaX).clamp(0.0, max);
    _scrollController.jumpTo(nextOffset);
  }

  Widget _buildThumbnailStrip(double timelineWidth) {
    if (widget.thumbnails.isEmpty) {
      _cachedThumbnailStrip = null;
      _cachedThumbnailSignature = 0;
      _cachedThumbnailTimelineWidth = -1;
      return const Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0x22162A3C)),
            child: Center(
              child: Text(
                'サムネイル読み込み中...',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    }

    final signature = Object.hashAll(
      widget.thumbnails.map((item) => item.path),
    );
    final widthStable =
        (timelineWidth - _cachedThumbnailTimelineWidth).abs() < 0.5;
    if (_cachedThumbnailStrip != null &&
        signature == _cachedThumbnailSignature &&
        widthStable) {
      return _cachedThumbnailStrip!;
    }

    final tileWidth = timelineWidth / widget.thumbnails.length;
    final strip = Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: widget.thumbnails.map((thumbnail) {
            return SizedBox(
              width: tileWidth,
              child: Image.file(
                File(thumbnail.path),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(color: Color(0x22000000));
                },
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );

    _cachedThumbnailStrip = strip;
    _cachedThumbnailSignature = signature;
    _cachedThumbnailTimelineWidth = timelineWidth;
    return strip;
  }

  Widget _buildMarkers(
    double timelineWidth,
    double markerStep,
    double pxPerSecond,
  ) {
    final markerCount = (_totalSeconds / markerStep).ceil() + 1;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white70,
          fontSize: 10,
        );

    return IgnorePointer(
      child: SizedBox(
        width: timelineWidth,
        child: Stack(
          children: List<Widget>.generate(markerCount, (index) {
            final seconds = (index * markerStep).clamp(0, _totalSeconds);
            final x = _secondsToPx(seconds.toDouble(), pxPerSecond);
            return Positioned(
              left: x,
              top: 0,
              bottom: 0,
              child: Column(
                children: <Widget>[
                  Container(
                    width: 1,
                    height: 14,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatSeconds(seconds.toDouble()),
                    style: labelStyle,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTrimHandle({
    required Key key,
    required double x,
    required Color color,
    required VoidCallback onDragStart,
    required ValueChanged<double> onDrag,
    required VoidCallback onDragEnd,
  }) {
    return Positioned(
      left: x - 7,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd(),
        onHorizontalDragCancel: onDragEnd,
        child: SizedBox(
          width: 14,
          child: Center(
            child: Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _secondsToPx(double seconds, double pxPerSecond) {
    return seconds.clamp(0.0, _totalSeconds) * pxPerSecond;
  }

  double _pxToSeconds(double px, double pxPerSecond) {
    if (pxPerSecond <= 0) return 0;
    return (px / pxPerSecond).clamp(0.0, _totalSeconds).toDouble();
  }

  double _resolveMarkerStep(double pxPerSecond) {
    const candidates = <double>[0.5, 1, 2, 5, 10, 15, 30, 60];
    for (final candidate in candidates) {
      if (candidate * pxPerSecond >= 56) {
        return candidate;
      }
    }
    return 60;
  }

  String _formatSeconds(double seconds) {
    final total = seconds.round();
    final minutes = total ~/ 60;
    final remain = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
  }
}
