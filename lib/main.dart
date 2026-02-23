import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/launch_file_service.dart';
import 'src/state/app_controller.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final launchFileService = LaunchFileService(startupArgs: args);
  await launchFileService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppController(launchFileService: launchFileService),
      child: const LoopEditorApp(),
    ),
  );
}
