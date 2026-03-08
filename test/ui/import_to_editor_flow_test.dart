import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/app_strings.dart';
import 'package:gintoolflutter/src/ui/screens/import_screen.dart';

void main() {
  testWidgets('インポート画面の主要UIが表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ImportScreen(onVideoSelected: (_) {})),
    );

    expect(find.text(AppStrings.importScreenTitle), findsOneWidget);
    expect(find.text(AppStrings.openFromFile), findsOneWidget);
    expect(find.text(AppStrings.openFromLibrary), findsOneWidget);
  });
}
