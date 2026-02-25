import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/file_import_service.dart';
import '../../state/app_controller.dart';
import 'editor_screen.dart';
import 'import_screen.dart';

class RootScreen extends StatelessWidget {
  RootScreen({super.key});

  final FileImportService _fileImportService = FileImportService();

  Future<void> _openFromFilesApp(AppController appController) async {
    final path = await _fileImportService.pickVideoFromFileApp(
      dialogTitle: 'ファイルアプリから動画を選択',
    );
    if (path == null) return;

    final validationError = _fileImportService.validateVideoPath(path);
    if (validationError != null) {
      return;
    }
    appController.openInputPath(path, replaceCurrent: true);
  }

  Future<void> _openFromPhotoLibrary(AppController appController) async {
    final path = await _fileImportService.pickVideoFromPhotoLibrary();
    if (path == null) return;

    final validationError = _fileImportService.validateVideoPath(path);
    if (validationError != null) {
      return;
    }
    appController.openInputPath(path, replaceCurrent: true);
  }

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
          onRequestOpenFromFiles: () => _openFromFilesApp(appController),
          onRequestOpenFromLibrary: () => _openFromPhotoLibrary(appController),
          onReplaceInputPath: (path) {
            appController.openInputPath(path, replaceCurrent: true);
          },
        );
      },
    );
  }
}
