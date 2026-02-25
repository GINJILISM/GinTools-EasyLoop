import 'package:flutter/material.dart';

import 'ui/screens/root_screen.dart';

class LoopEditorApp extends StatelessWidget {
  const LoopEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GinTools-EasyLoop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F5C73),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF112F48),
        useMaterial3: true,
      ),
      home: RootScreen(),
    );
  }
}
