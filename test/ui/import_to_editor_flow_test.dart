import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/screens/import_screen.dart';

void main() {
  testWidgets('インポート画面の主要UIが表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ImportScreen(onVideoSelected: (_) {})),
    );

    expect(find.text('編集する動画を選択'), findsOneWidget);
    expect(find.text('ファイルから開く'), findsOneWidget);
    expect(find.text('ライブラリから開く'), findsOneWidget);
  });
}
