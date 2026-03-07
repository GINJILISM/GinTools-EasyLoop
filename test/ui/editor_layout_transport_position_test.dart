import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/widgets/editor_shell.dart';
import 'package:gintoolflutter/src/ui/widgets/playback_transport_bar.dart';
import 'package:gintoolflutter/src/ui/widgets/preview_stage.dart';

void main() {
  testWidgets('トランスポートがプレビュー下部にあり、設定パネルが表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditorShell(
          title: 'sample.mp4',
          onImportDefaultRequested: () {},
          onImportFromFilesRequested: () {},
          onImportFromLibraryRequested: () {},
          preview: PreviewStage(
            video: const ColoredBox(color: Colors.black),
            positionLabel: '00:01 (start 0.00s / end 5.00s)',
            isPingPong: false,
            isReverseDirection: false,
            bottomOverlay: PlaybackTransportBar(
              isPlaying: false,
              isDisabled: false,
              onSetStart: () {},
              onJumpStart: () {},
              onStepPrev: () {},
              onPlayPause: () {},
              onStepNext: () {},
              onJumpEnd: () {},
              onSetEnd: () {},
            ),
          ),
          timeline: const SizedBox.expand(),
          controls: const Text('設定パネル'),
        ),
      ),
    );

    expect(find.byKey(const Key('preview-transport-overlay')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('preview-transport-overlay')),
        matching: find.byType(PreviewStage),
      ),
      findsOneWidget,
    );
    expect(find.text('設定パネル'), findsOneWidget);
  });
}
