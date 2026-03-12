import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/launch_file_service.dart';
import 'src/state/app_controller.dart';

Future<void> main(List<String> args) async {
  final startupTimer = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Startup] WidgetsFlutterBinding ready: ${startupTimer.elapsedMilliseconds}ms');

  final launchFileService = LaunchFileService(startupArgs: args);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppController(launchFileService: launchFileService),
      child: const LoopEditorApp(),
    ),
  );
  debugPrint('[Startup] runApp called: ${startupTimer.elapsedMilliseconds}ms');
}
