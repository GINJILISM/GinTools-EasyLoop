import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/widgets/playback_transport_bar.dart';

void main() {
  testWidgets('7ボタンが表示され、再生状態でアイコンが切り替わる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackTransportBar(
            isPlaying: true,
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
      ),
    );

    expect(find.byKey(const Key('transport-set-start')), findsOneWidget);
    expect(find.byKey(const Key('transport-trim-start')), findsOneWidget);
    expect(find.byKey(const Key('transport-frame-prev')), findsOneWidget);
    expect(find.byKey(const Key('transport-play-pause')), findsOneWidget);
    expect(find.byKey(const Key('transport-frame-next')), findsOneWidget);
    expect(find.byKey(const Key('transport-trim-end')), findsOneWidget);
    expect(find.byKey(const Key('transport-set-end')), findsOneWidget);

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('押下で各コールバックが発火する', (tester) async {
    var count = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackTransportBar(
            isPlaying: false,
            isDisabled: false,
            onSetStart: () => count++,
            onJumpStart: () => count++,
            onStepPrev: () => count++,
            onPlayPause: () => count++,
            onStepNext: () => count++,
            onJumpEnd: () => count++,
            onSetEnd: () => count++,
          ),
        ),
      ),
    );

    for (final key in <Key>[
      const Key('transport-set-start'),
      const Key('transport-trim-start'),
      const Key('transport-frame-prev'),
      const Key('transport-play-pause'),
      const Key('transport-frame-next'),
      const Key('transport-trim-end'),
      const Key('transport-set-end'),
    ]) {
      await tester.tap(find.byKey(key));
      await tester.pump();
    }

    expect(count, 7);
  });

  testWidgets('無効化時は押下されない', (tester) async {
    var count = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackTransportBar(
            isPlaying: false,
            isDisabled: true,
            onSetStart: () => count++,
            onJumpStart: () => count++,
            onStepPrev: () => count++,
            onPlayPause: () => count++,
            onStepNext: () => count++,
            onJumpEnd: () => count++,
            onSetEnd: () => count++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('transport-play-pause')));
    await tester.pump();

    expect(count, 0);
  });
}
