import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/widgets/preview_stage.dart';

void main() {
  testWidgets('bottomOverlay が表示され、余計な再生FABは表示されない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreviewStage(
            video: const ColoredBox(color: Colors.black),
            positionLabel: '00:01 (start 0.00s / end 5.00s)',
            isPingPong: true,
            isReverseDirection: false,
            bottomOverlay: const SizedBox(
              key: Key('overlay-test-key'),
              width: 100,
              height: 32,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('overlay-test-key')), findsOneWidget);
    expect(find.byKey(const Key('preview_play_pause')), findsNothing);
    expect(find.text('00:01 (start 0.00s / end 5.00s)'), findsOneWidget);
  });
}
