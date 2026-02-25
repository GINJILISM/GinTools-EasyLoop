import Flutter
import UIKit

enum SharedMediaBridge {
  static let channelName = "com.gintoolflutter.launch/open_file"

  static func post(path: String) {
    post(paths: [path])
  }

  static func post(paths: [String]) {
    let trimmed = paths
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !trimmed.isEmpty else {
      return
    }

    let payload: [String: Any] = [
      "path": trimmed.first ?? "",
      "paths": trimmed
    ]

    DispatchQueue.main.async {
      NotificationCenter.default.post(
        name: .easyLoopIncomingPaths,
        object: nil,
        userInfo: ["payload": payload]
      )
    }
  }

  static func materializeIncomingUrl(_ url: URL) -> URL? {
    let wasAccessed = url.startAccessingSecurityScopedResource()
    defer {
      if wasAccessed {
        url.stopAccessingSecurityScopedResource()
      }
    }

    guard url.isFileURL else {
      return nil
    }

    let fileManager = FileManager.default
    let inboxRoot = fileManager.temporaryDirectory
      .appendingPathComponent("easyloop_inbox", isDirectory: true)

    do {
      try fileManager.createDirectory(
        at: inboxRoot,
        withIntermediateDirectories: true
      )

      let ext = url.pathExtension
      let baseName = url.deletingPathExtension().lastPathComponent
      let safeBase = baseName.isEmpty ? "shared_video" : baseName
      let filename = ext.isEmpty
        ? "\(UUID().uuidString)_\(safeBase)"
        : "\(UUID().uuidString)_\(safeBase).\(ext)"
      let destination = inboxRoot.appendingPathComponent(filename)

      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }
      try fileManager.copyItem(at: url, to: destination)
      return destination
    } catch {
      return nil
    }
  }
}

private extension Notification.Name {
  static let easyLoopIncomingPaths = Notification.Name("EasyLoopIncomingPaths")
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var launchChannel: FlutterMethodChannel?
  private var pendingPayloads: [[String: Any]] = []
  private var incomingObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    GeneratedPluginRegistrant.register(with: self)
    configureLaunchChannelIfNeeded()
    registerIncomingObserver()
    return didFinish
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let materialized = SharedMediaBridge.materializeIncomingUrl(url) {
      SharedMediaBridge.post(path: materialized.path)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  deinit {
    if let observer = incomingObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func registerIncomingObserver() {
    incomingObserver = NotificationCenter.default.addObserver(
      forName: .easyLoopIncomingPaths,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let payload = notification.userInfo?["payload"] as? [String: Any]
      else {
        return
      }
      self?.enqueue(payload: payload)
    }
  }

  private func enqueue(payload: [String: Any]) {
    pendingPayloads.append(payload)
    configureLaunchChannelIfNeeded()
    flushPendingPayloadsIfNeeded()
  }

  private func configureLaunchChannelIfNeeded() {
    guard launchChannel == nil else {
      return
    }
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    launchChannel = FlutterMethodChannel(
      name: SharedMediaBridge.channelName,
      binaryMessenger: controller.binaryMessenger
    )
  }

  private func flushPendingPayloadsIfNeeded() {
    guard let launchChannel, !pendingPayloads.isEmpty else {
      return
    }

    let payloads = pendingPayloads
    pendingPayloads.removeAll()

    for payload in payloads {
      launchChannel.invokeMethod("onReceiveSharedMedia", arguments: payload)
    }
  }
}
