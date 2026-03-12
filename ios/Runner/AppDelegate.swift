import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var openFileChannel: FlutterMethodChannel?
  private var pendingOpenPaths: [String] = []
  private var isFlutterReadyForOpenFileEvents = false
  private var sharedMediaObserver: NSObjectProtocol?

  static var shared: AppDelegate? {
    UIApplication.shared.delegate as? AppDelegate
  }

  deinit {
    if let sharedMediaObserver {
      NotificationCenter.default.removeObserver(sharedMediaObserver)
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    sharedMediaObserver = NotificationCenter.default.addObserver(
      forName: .easyLoopIncomingPaths,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let payload = notification.userInfo?["payload"] as? [String: Any]
      else {
        return
      }
      self?.handleIncomingPayload(payload)
    }

    let didLaunch = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    DispatchQueue.main.async { [weak self] in
      self?.configureLaunchChannelIfNeeded()
      self?.consumePendingSharedInboxFilesIfNeeded()
    }

    return didLaunch
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    DispatchQueue.main.async { [weak self] in
      self?.configureLaunchChannelIfNeeded()
      self?.consumePendingSharedInboxFilesIfNeeded()
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    configureLaunchChannelIfNeeded()
    consumePendingSharedInboxFilesIfNeeded()
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if SharedMediaBridge.consumeIncomingUrl(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func configureLaunchChannelIfNeeded() {
    if openFileChannel != nil {
      return
    }

    guard let flutterViewController = currentFlutterViewController() else {
      return
    }

    isFlutterReadyForOpenFileEvents = false
    let channel = FlutterMethodChannel(
      name: SharedMediaBridge.channelName,
      binaryMessenger: flutterViewController.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "notifyFlutterReady":
        self.isFlutterReadyForOpenFileEvents = true
        result(nil)
      case "consumePendingOpenFiles":
        let pending = self.pendingOpenPaths
        self.pendingOpenPaths.removeAll()
        result(pending)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    openFileChannel = channel
  }

  func consumePendingSharedInboxFilesIfNeeded() {
    let importedCount = SharedMediaBridge.consumePendingSharedInboxFiles()
    if importedCount > 0 {
      NSLog("[SharedMedia] consumed %d pending file(s) from shared inbox", importedCount)
    }
  }

  private func handleIncomingPayload(_ payload: [String: Any]) {
    let paths = extractPaths(from: payload)
    guard !paths.isEmpty else {
      return
    }

    if let openFileChannel, isFlutterReadyForOpenFileEvents {
      openFileChannel.invokeMethod(
        "onOpenFile",
        arguments: [
          "path": paths.first ?? "",
          "paths": paths
        ]
      )
      return
    }

    pendingOpenPaths.append(contentsOf: paths)
  }

  private func extractPaths(from payload: [String: Any]) -> [String] {
    var paths: [String] = []

    if let path = payload["path"] as? String {
      let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        paths.append(trimmed)
      }
    }

    if let rawPaths = payload["paths"] as? [String] {
      for rawPath in rawPaths {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !paths.contains(trimmed) {
          paths.append(trimmed)
        }
      }
    }

    return paths
  }

  private func currentFlutterViewController() -> FlutterViewController? {
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else {
        continue
      }

      for window in windowScene.windows {
        if let flutterViewController = findFlutterViewController(
          in: window.rootViewController
        ) {
          return flutterViewController
        }
      }
    }

    return nil
  }

  private func findFlutterViewController(
    in viewController: UIViewController?
  ) -> FlutterViewController? {
    guard let viewController else {
      return nil
    }

    if let flutterViewController = viewController as? FlutterViewController {
      return flutterViewController
    }

    if let navigationController = viewController as? UINavigationController {
      if let flutterViewController = findFlutterViewController(
        in: navigationController.visibleViewController
      ) {
        return flutterViewController
      }
    }

    if let tabBarController = viewController as? UITabBarController {
      if let flutterViewController = findFlutterViewController(
        in: tabBarController.selectedViewController
      ) {
        return flutterViewController
      }
    }

    if let presentedViewController = viewController.presentedViewController {
      if let flutterViewController = findFlutterViewController(
        in: presentedViewController
      ) {
        return flutterViewController
      }
    }

    for child in viewController.children {
      if let flutterViewController = findFlutterViewController(in: child) {
        return flutterViewController
      }
    }

    return nil
  }
}
