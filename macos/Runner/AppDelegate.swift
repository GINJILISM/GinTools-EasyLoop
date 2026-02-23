import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let openFileChannelName = "com.gintoolflutter.launch/open_file"
  private var openFileChannel: FlutterMethodChannel?
  private var pendingPaths: [String] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let flutterViewController = mainFlutterWindow.contentViewController as? FlutterViewController {
      openFileChannel = FlutterMethodChannel(
        name: openFileChannelName,
        binaryMessenger: flutterViewController.engine.binaryMessenger
      )
    }

    flushPendingPathsIfNeeded()
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ application: NSApplication, openFiles filenames: [String]) {
    for path in filenames {
      sendPathToFlutter(path)
    }
    NSApp.reply(toOpenOrPrint: .success)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func sendPathToFlutter(_ path: String) {
    guard let channel = openFileChannel else {
      pendingPaths.append(path)
      return
    }

    channel.invokeMethod(
      "onOpenFile",
      arguments: ["path": path]
    )
  }

  private func flushPendingPathsIfNeeded() {
    guard !pendingPaths.isEmpty, openFileChannel != nil else {
      return
    }
    pendingPaths.forEach { sendPathToFlutter($0) }
    pendingPaths.removeAll()
  }
}
