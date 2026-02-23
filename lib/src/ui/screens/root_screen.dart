import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import 'editor_screen.dart';
import 'import_screen.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, appController, child) {
        final inputPath = appController.inputPath;
        if (inputPath == null) {
          return ImportScreen(onVideoSelected: appController.openInputPath);
        }

        return EditorScreen(
          key: ValueKey<String>('$inputPath#${appController.sessionVersion}'),
          inputPath: inputPath,
          onCloseRequested: appController.closeEditor,
          onReplaceInputPath: (path) {
            appController.openInputPath(path, replaceCurrent: true);
          },
        );
      },
    );
  }
}
