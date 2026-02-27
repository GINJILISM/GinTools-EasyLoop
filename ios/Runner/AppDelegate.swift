import Flutter
import UIKit

enum SharedMediaBridge {
  static let channelName = "com.gintoolflutter.launch/open_file"
  static let appGroupIdentifier = "group.com.ginjilism.gintool"

  private static let sharedInboxFolderName = "incoming_share"
  private static let importScheme = "easyloop"
  private static let importHost = "import-shared"

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
    let start = CFAbsoluteTimeGetCurrent()
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

      let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
      NSLog("[SharedMedia] materialized in %dms: %@", elapsedMs, destination.lastPathComponent)
      return destination
    } catch {
      let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
      NSLog("[SharedMedia] materialize failed in %dms: %@", elapsedMs, error.localizedDescription)
      return nil
    }
  }

  static func consumeIncomingUrl(_ url: URL) -> Bool {
    if url.isFileURL, let materialized = materializeIncomingUrl(url) {
      post(path: materialized.path)
      return true
    }

    if let materialized = materializeFromAppGroup(url) {
      post(path: materialized.path)
      return true
    }

    return false
  }

  static func consumePendingSharedInboxFiles() -> Int {
    let fileManager = FileManager.default
    guard let containerUrl = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      return 0
    }

    let inbox = containerUrl.appendingPathComponent(sharedInboxFolderName, isDirectory: true)
    guard let urls = try? fileManager.contentsOfDirectory(
      at: inbox,
      includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return 0
    }

    let regularFiles = urls.filter { url in
      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    if regularFiles.isEmpty {
      return 0
    }

    let sortedFiles = regularFiles.sorted { lhs, rhs in
      let leftDate =
        (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        ?? .distantPast
      let rightDate =
        (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        ?? .distantPast
      return leftDate < rightDate
    }

    var importedPaths: [String] = []
    for source in sortedFiles {
      guard let materialized = materializeIncomingUrl(source) else {
        continue
      }
      importedPaths.append(materialized.path)
      try? fileManager.removeItem(at: source)
    }

    post(paths: importedPaths)
    return importedPaths.count
  }

  private static func materializeFromAppGroup(_ url: URL) -> URL? {
    guard
      let scheme = url.scheme?.lowercased(),
      scheme == importScheme,
      url.host == importHost
    else {
      return nil
    }

    guard
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let fileName = components.queryItems?
        .first(where: { $0.name == "file" })?
        .value,
      !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      NSLog("[SharedMedia] Missing file parameter in URL: %@", url.absoluteString)
      return nil
    }

    let fileManager = FileManager.default
    guard let containerUrl = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      NSLog("[SharedMedia] App Group container unavailable: %@", appGroupIdentifier)
      return nil
    }

    let source = containerUrl
      .appendingPathComponent(sharedInboxFolderName, isDirectory: true)
      .appendingPathComponent(fileName)

    guard fileManager.fileExists(atPath: source.path) else {
      NSLog("[SharedMedia] Shared file not found: %@", source.path)
      return nil
    }

    guard let materialized = materializeIncomingUrl(source) else {
      return nil
    }

    try? fileManager.removeItem(at: source)
    return materialized
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
    GeneratedPluginRegistrant.register(with: self)
    configureLaunchChannelIfNeeded()
    registerIncomingObserver()
    let consumed = SharedMediaBridge.consumePendingSharedInboxFiles()
    if consumed > 0 {
      NSLog("[SharedMedia] consumed pending inbox files at launch: %d", consumed)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    configureLaunchChannelIfNeeded()
    flushPendingPayloadsIfNeeded()
    let consumed = SharedMediaBridge.consumePendingSharedInboxFiles()
    if consumed > 0 {
      NSLog("[SharedMedia] consumed pending inbox files on active: %d", consumed)
    }
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
    NSLog("[SharedMedia] queued payloads: %d", pendingPayloads.count)
    configureLaunchChannelIfNeeded()
    flushPendingPayloadsIfNeeded()
  }

  private func configureLaunchChannelIfNeeded() {
    guard launchChannel == nil else {
      return
    }

    guard let controller = resolveFlutterViewController() else {
      NSLog("[SharedMedia] FlutterViewController not ready yet")
      return
    }

    launchChannel = FlutterMethodChannel(
      name: SharedMediaBridge.channelName,
      binaryMessenger: controller.binaryMessenger
    )
    NSLog("[SharedMedia] launch channel configured")
  }

  private func flushPendingPayloadsIfNeeded() {
    guard let launchChannel, !pendingPayloads.isEmpty else {
      return
    }

    let payloads = pendingPayloads
    pendingPayloads.removeAll()
    NSLog("[SharedMedia] flushing payload count: %d", payloads.count)

    for payload in payloads {
      launchChannel.invokeMethod("onReceiveSharedMedia", arguments: payload)
    }
  }

  private func resolveFlutterViewController() -> FlutterViewController? {
    if let direct = window?.rootViewController as? FlutterViewController {
      return direct
    }

    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else {
        continue
      }

      for window in windowScene.windows {
        if let controller = findFlutterViewController(from: window.rootViewController) {
          return controller
        }
      }
    }

    return nil
  }

  private func findFlutterViewController(from root: UIViewController?) -> FlutterViewController? {
    guard let root else {
      return nil
    }

    if let flutter = root as? FlutterViewController {
      return flutter
    }

    if let flutter = findInContainerControllers(root) {
      return flutter
    }

    return findInDescendants(root)
  }

  private func findInContainerControllers(_ root: UIViewController) -> FlutterViewController? {
    if let navigation = root as? UINavigationController {
      for controller in navigation.viewControllers {
        if let flutter = findFlutterViewController(from: controller) {
          return flutter
        }
      }
    }

    if let tab = root as? UITabBarController {
      for controller in tab.viewControllers ?? [] {
        if let flutter = findFlutterViewController(from: controller) {
          return flutter
        }
      }
    }

    return nil
  }

  private func findInDescendants(_ root: UIViewController) -> FlutterViewController? {
    if let presented = root.presentedViewController,
      let flutter = findFlutterViewController(from: presented) {
      return flutter
    }

    for child in root.children {
      if let flutter = findFlutterViewController(from: child) {
        return flutter
      }
    }

    return nil
  }
}
