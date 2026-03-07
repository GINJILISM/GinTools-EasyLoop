import '../ui/app_strings.dart';

enum LoopMode {
  forward,
  pingPong;

  String get label {
    switch (this) {
      case LoopMode.forward:
        return AppStrings.loopModeForwardLabel;
      case LoopMode.pingPong:
        return AppStrings.loopModePingPongLabel;
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
