import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/launch_file_service.dart';
import 'src/state/app_controller.dart';

Future<void> main(List<String> args) async {
  final startupTimer = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Startup] WidgetsFlutterBinding ready: ${startupTimer.elapsedMilliseconds}ms');
  MediaKit.ensureInitialized();
  debugPrint('[Startup] MediaKit initialized: ${startupTimer.elapsedMilliseconds}ms');

  final launchFileService = LaunchFileService(startupArgs: args);
  await launchFileService.initialize();
  debugPrint('[Startup] LaunchFileService initialized: ${startupTimer.elapsedMilliseconds}ms');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppController(launchFileService: launchFileService),
      child: const LoopEditorApp(),
    ),
  );
  debugPrint('[Startup] runApp called: ${startupTimer.elapsedMilliseconds}ms');
}
