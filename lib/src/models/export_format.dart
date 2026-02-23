enum ExportFormat {
  mp4,
  gif;

  String get label {
    switch (this) {
      case ExportFormat.mp4:
        return 'MP4';
      case ExportFormat.gif:
        return 'GIF';
    }
  }

  String get extension {
    switch (this) {
      case ExportFormat.mp4:
        return 'mp4';
      case ExportFormat.gif:
        return 'gif';
    }
  }
}
