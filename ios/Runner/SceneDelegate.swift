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

extension Notification.Name {
	static let easyLoopIncomingPaths = Notification.Name("EasyLoopIncomingPaths")
}

class SceneDelegate: FlutterSceneDelegate {
	override func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		super.scene(scene, willConnectTo: session, options: connectionOptions)

		handleIncomingUrls(connectionOptions.urlContexts.map(\.url))
		AppDelegate.shared?.configureLaunchChannelIfNeeded()
		AppDelegate.shared?.consumePendingSharedInboxFilesIfNeeded()
	}

	override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		super.scene(scene, openURLContexts: URLContexts)
		handleIncomingUrls(URLContexts.map(\.url))
	}

	override func sceneDidBecomeActive(_ scene: UIScene) {
		super.sceneDidBecomeActive(scene)
		AppDelegate.shared?.configureLaunchChannelIfNeeded()
		AppDelegate.shared?.consumePendingSharedInboxFilesIfNeeded()
	}

	private func handleIncomingUrls(_ urls: [URL]) {
		for url in urls {
			_ = SharedMediaBridge.consumeIncomingUrl(url)
		}
	}
}
