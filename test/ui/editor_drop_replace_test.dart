import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/widgets/replace_input_dialog.dart';

class _DropReplaceHarness extends StatelessWidget {
  const _DropReplaceHarness({required this.onReplace});

  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final approved = await showReplaceInputDialog(context);
                if (approved) {
                  onReplace();
                }
              },
              child: const Text('drop'),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('編集中ドロップ時に確認ダイアログが表示される', (tester) async {
    await tester.pumpWidget(_DropReplaceHarness(onReplace: () {}));

    await tester.tap(find.text('drop'));
    await tester.pumpAndSettle();

    expect(find.text('別動画に切り替えますか？'), findsOneWidget);
    expect(find.text('現在の編集状態は破棄されます。'), findsOneWidget);
  });

  testWidgets('承認すると置換コールバックが発火する', (tester) async {
    var replaced = false;
    await tester.pumpWidget(
      _DropReplaceHarness(onReplace: () => replaced = true),
    );

    await tester.tap(find.text('drop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切り替える'));
    await tester.pumpAndSettle();

    expect(replaced, isTrue);
  });
}
