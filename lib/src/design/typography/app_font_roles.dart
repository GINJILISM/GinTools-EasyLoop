import 'package:flutter/material.dart';

class AppFontRoles {
  AppFontRoles._();

  static const String yadewanoji = 'Yadewanoji';

  static TextStyle? screenHeadline(TextStyle? base) {
    return base?.copyWith(fontFamily: yadewanoji);
  }

  static TextStyle? dialogTitle(TextStyle? base) {
    return base?.copyWith(fontFamily: yadewanoji);
  }

  static TextStyle? actionButtonLabel(TextStyle? base) {
    return base?.copyWith(fontFamily: yadewanoji);
  }
}
