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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final timelineHeight = (constraints.maxHeight * 0.45).clamp(
                    64.0,
                    180.0,
                  );
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: <Widget>[
                        SizedBox(height: timelineHeight, child: timeline),
                        const SizedBox(height: 8),
                        Expanded(child: SingleChildScrollView(child: controls)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w500);

    return Scaffold(
      appBar: AppBar(
        title: Text('\u7de8\u96c6\u4e2d: $title', style: titleStyle),
        actions: <Widget>[
          TextButton.icon(
            onPressed: onCloseRequested,
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('\u52d5\u753b\u3092\u9078\u629e'),
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
                    color: Colors.lightBlueAccent.withOpacity(0.18),
                    border: Border.all(color: Colors.lightBlueAccent, width: 3),
                  ),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                            '\u3053\u3053\u306b\u30c9\u30ed\u30c3\u30d7\u3057\u3066\u52d5\u753b\u3092\u7f6e\u304d\u63db\u3048'),
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
