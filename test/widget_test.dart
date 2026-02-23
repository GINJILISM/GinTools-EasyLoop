import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/models/loop_mode.dart';

void main() {
  test('LoopModeのラベルが正しい', () {
    expect(LoopMode.forward.label, '→ 通常ループ');
    expect(LoopMode.pingPong.label, '←→ ピンポン');
  });
}
