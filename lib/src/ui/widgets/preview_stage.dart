import 'package:flutter/material.dart';

class PreviewStage extends StatelessWidget {
  const PreviewStage({
    super.key,
    required this.video,
    required this.isPlaying,
    required this.onPlayPause,
    required this.positionLabel,
    required this.isPingPong,
    required this.isReverseDirection,
  });

  final Widget video;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final String positionLabel;
  final bool isPingPong;
  final bool isReverseDirection;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: Colors.black, child: video),
          Positioned(
            top: 14,
            left: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(positionLabel),
              ),
            ),
          ),
          if (isPingPong)
            Positioned(
              top: 14,
              right: 14,
              child: Chip(
                label: Text(isReverseDirection ? 'ピンポン: 逆方向' : 'ピンポン: 順方向'),
              ),
            ),
          Positioned(
            left: 14,
            bottom: 14,
            child: FloatingActionButton.small(
              heroTag: 'preview_play_pause',
              onPressed: onPlayPause,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
