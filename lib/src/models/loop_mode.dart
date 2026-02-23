enum LoopMode {
  forward,
  pingPong;

  String get label {
    switch (this) {
      case LoopMode.forward:
        return '→ 通常ループ';
      case LoopMode.pingPong:
        return '←→ ピンポン';
    }
  }

  String get shortLabel {
    switch (this) {
      case LoopMode.forward:
        return '→';
      case LoopMode.pingPong:
        return '←→';
    }
  }
}
