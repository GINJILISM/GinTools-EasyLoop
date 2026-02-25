import Flutter
import UIKit

private enum SharedMediaBridge {
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

  static func normalizeIncomingUrl(_ url: URL) -> URL? {
    if url.isFileURL {
      return url
    }

    guard url.startAccessingSecurityScopedResource() else {
      return nil
    }
    defer {
      url.stopAccessingSecurityScopedResource()
    }

    return url
  }
}

private extension Notification.Name {
  static let easyLoopIncomingPaths = Notification.Name("EasyLoopIncomingPaths")
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var launchChannel: FlutterMethodChannel?
  private var pendingPayloads: [[String: Any]] = []
  private var incomingObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    registerIncomingObserver()
    return didFinish
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let normalized = SharedMediaBridge.normalizeIncomingUrl(url) {
      SharedMediaBridge.post(path: normalized.path)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: SharedMediaBridge.channelName,
      binaryMessenger: engineBridge.binaryMessenger
    )
    launchChannel = channel
    flushPendingPayloadsIfNeeded()
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
    flushPendingPayloadsIfNeeded()
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
