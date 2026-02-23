import 'package:flutter/material.dart';

class PlaybackTransportBar extends StatelessWidget {
  const PlaybackTransportBar({
    super.key,
    required this.isPlaying,
    required this.isDisabled,
    required this.onSetStart,
    required this.onJumpStart,
    required this.onStepPrev,
    required this.onPlayPause,
    required this.onStepNext,
    required this.onJumpEnd,
    required this.onSetEnd,
  });

  final bool isPlaying;
  final bool isDisabled;

  final VoidCallback onSetStart;
  final VoidCallback onJumpStart;
  final VoidCallback onStepPrev;
  final VoidCallback onPlayPause;
  final VoidCallback onStepNext;
  final VoidCallback onJumpEnd;
  final VoidCallback onSetEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      key: const Key('preview-transport-overlay'),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildIconButton(
              context: context,
              key: const Key('transport-set-start'),
              icon: Icons.first_page_rounded,
              tooltip: '現在位置を開始点に設定',
              onPressed: onSetStart,
            ),
            _buildIconButton(
              context: context,
              key: const Key('transport-trim-start'),
              icon: Icons.skip_previous_rounded,
              tooltip: '開始点へ移動',
              onPressed: onJumpStart,
            ),
            _buildIconButton(
              context: context,
              key: const Key('transport-frame-prev'),
              icon: Icons.fast_rewind_rounded,
              tooltip: '1フレーム戻る',
              onPressed: onStepPrev,
            ),
            Tooltip(
              message: isPlaying ? '一時停止' : '再生',
              child: FilledButton.tonal(
                key: const Key('transport-play-pause'),
                onPressed: isDisabled ? null : onPlayPause,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 40),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 22,
                ),
              ),
            ),
            _buildIconButton(
              context: context,
              key: const Key('transport-frame-next'),
              icon: Icons.fast_forward_rounded,
              tooltip: '1フレーム進む',
              onPressed: onStepNext,
            ),
            _buildIconButton(
              context: context,
              key: const Key('transport-trim-end'),
              icon: Icons.skip_next_rounded,
              tooltip: '終了点へ移動',
              onPressed: onJumpEnd,
            ),
            _buildIconButton(
              context: context,
              key: const Key('transport-set-end'),
              icon: Icons.last_page_rounded,
              tooltip: '現在位置を終了点に設定',
              onPressed: onSetEnd,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: key,
        onPressed: isDisabled ? null : onPressed,
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
      ),
    );
  }
}
