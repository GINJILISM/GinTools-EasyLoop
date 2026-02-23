import 'package:flutter/material.dart';

class EditorShell extends StatelessWidget {
  const EditorShell({
    super.key,
    required this.title,
    required this.preview,
    required this.timeline,
    required this.controls,
    required this.onCloseRequested,
    this.showDropHighlight = false,
  });

  final String title;
  final Widget preview;
  final Widget timeline;
  final Widget controls;
  final VoidCallback onCloseRequested;
  final bool showDropHighlight;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Expanded(flex: 6, child: preview),
          const SizedBox(height: 12),
          Expanded(
            flex: 4,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    SizedBox(height: 180, child: timeline),
                    const SizedBox(height: 10),
                    Expanded(child: SingleChildScrollView(child: controls)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('編集中: $title'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: onCloseRequested,
            icon: const Icon(Icons.home_rounded),
            label: const Text('ホーム'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: <Widget>[
          body,
          if (showDropHighlight)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.lightBlueAccent, width: 3),
                  ),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text('ここにドロップして別動画へ切替'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
