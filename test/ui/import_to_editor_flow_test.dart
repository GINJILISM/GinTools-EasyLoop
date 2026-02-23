import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/screens/import_screen.dart';

void main() {
  testWidgets('インポート画面の主要UIが表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ImportScreen(onVideoSelected: (_) {})),
    );

    expect(find.text('動画をここへドロップ'), findsOneWidget);
    expect(find.text('動画を選択'), findsOneWidget);
  });
}
