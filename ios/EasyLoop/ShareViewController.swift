import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private static let appGroupIdentifier = "group.com.ginjilism.gintool"
    private static let sharedInboxDirectory = "incoming_share"
    private static let openScheme = "easyloop"
    private static let openHost = "import-shared"
    private var hasStarted = false

    private func trace(_ message: String) {
        NSLog("[ShareExtension] %@", message)
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
            return
        }
        defaults.set(message, forKey: "last_share_extension_event")
        defaults.set(Date().timeIntervalSince1970, forKey: "last_share_extension_event_at")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        preferredContentSize = CGSize(width: 1, height: 1)

        guard !hasStarted else {
            return
        }
        hasStarted = true
        trace("viewDidLoad start")
        Task {
            await processIncomingMovieAndOpenHost()
        }
    }

    private func processIncomingMovieAndOpenHost() async {
        guard let provider = firstMovieProvider() else {
            trace("no movie provider")
            completeExtensionRequest()
            return
        }

        do {
            let fileName = try await persistSharedMovie(from: provider)
            trace("persisted file: \(fileName)")
            _ = await openMainApp(withSharedFileName: fileName)
            trace("openMainApp called")
            completeExtensionRequest()
        } catch {
            trace("failed: \(error.localizedDescription)")
            completeExtensionRequest()
        }
    }

    private func firstMovieProvider() -> NSItemProvider? {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []

        for item in items {
            let attachments = item.attachments ?? []
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ||
                    provider.hasItemConformingToTypeIdentifier(UTType.video.identifier) {
                    return provider
                }
            }
        }

        return nil
    }

    private func preferredMovieTypeIdentifier(for provider: NSItemProvider) -> String {
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return UTType.movie.identifier
        }
        return UTType.video.identifier
    }

    private func persistSharedMovie(from provider: NSItemProvider) async throws -> String {
        let fileManager = FileManager.default
        guard let containerUrl = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else {
            throw NSError(
                domain: "ShareExtension",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "App Group container unavailable"]
            )
        }

        let inboxUrl = containerUrl.appendingPathComponent(
            Self.sharedInboxDirectory,
            isDirectory: true
        )
        try fileManager.createDirectory(at: inboxUrl, withIntermediateDirectories: true)

        do {
            return try await persistViaLoadItem(provider: provider, inboxUrl: inboxUrl)
        } catch {
            trace("loadItem fallback: \(error.localizedDescription)")
            return try await persistViaLoadFileRepresentation(provider: provider, inboxUrl: inboxUrl)
        }
    }

    private func persistViaLoadItem(
        provider: NSItemProvider,
        inboxUrl: URL
    ) async throws -> String {
        let typeIdentifier = preferredMovieTypeIdentifier(for: provider)

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                do {
                    let fileName = try self.persistLoadedItem(item, inboxUrl: inboxUrl)
                    continuation.resume(returning: fileName)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func persistViaLoadFileRepresentation(
        provider: NSItemProvider,
        inboxUrl: URL
    ) async throws -> String {
        let typeIdentifier = preferredMovieTypeIdentifier(for: provider)

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "ShareExtension",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "No file URL from provider"]
                        )
                    )
                    return
                }

                do {
                    let fileName = try self.copyFileToInbox(from: url, inboxUrl: inboxUrl)
                    continuation.resume(returning: fileName)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func persistLoadedItem(_ item: NSSecureCoding?, inboxUrl: URL) throws -> String {
        if let url = item as? URL {
            return try copyFileToInbox(from: url, inboxUrl: inboxUrl)
        }
        if let url = item as? NSURL {
            return try copyFileToInbox(from: url as URL, inboxUrl: inboxUrl)
        }
        if let data = item as? Data {
            return try writeDataToInbox(data, preferredExtension: "mp4", inboxUrl: inboxUrl)
        }
        if let data = item as? NSData {
            return try writeDataToInbox(data as Data, preferredExtension: "mp4", inboxUrl: inboxUrl)
        }

        throw NSError(
            domain: "ShareExtension",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Unsupported item type from provider"]
        )
    }

    private func copyFileToInbox(from sourceUrl: URL, inboxUrl: URL) throws -> String {
        let fileManager = FileManager.default
        let ext = sourceUrl.pathExtension.isEmpty ? "mov" : sourceUrl.pathExtension
        let fileName = "shared_\(UUID().uuidString).\(ext)"
        let destination = inboxUrl.appendingPathComponent(fileName)

        let accessed = sourceUrl.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceUrl.stopAccessingSecurityScopedResource()
            }
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceUrl, to: destination)
        return fileName
    }

    private func writeDataToInbox(
        _ data: Data,
        preferredExtension: String,
        inboxUrl: URL
    ) throws -> String {
        let fileName = "shared_\(UUID().uuidString).\(preferredExtension)"
        let destination = inboxUrl.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        return fileName
    }

    private func openMainApp(withSharedFileName fileName: String) async -> Bool {
        var components = URLComponents()
        components.scheme = Self.openScheme
        components.host = Self.openHost
        components.queryItems = [URLQueryItem(name: "file", value: fileName)]

        guard let url = components.url else {
            return false
        }

        let openedByContext = await withCheckedContinuation { continuation in
            extensionContext?.open(url) { success in
                continuation.resume(returning: success)
            }
        }
        trace("open via extensionContext success=\(openedByContext)")
        if openedByContext {
            return true
        }

        let openedByRuntime = openViaUIApplicationRuntime(url)
        trace("open via UIApplication runtime success=\(openedByRuntime)")
        if !openedByRuntime {
            trace("failed to open URL: \(url.absoluteString)")
        }
        return openedByRuntime
    }

    private func openViaUIApplicationRuntime(_ url: URL) -> Bool {
        guard
            let appClass = NSClassFromString("UIApplication") as? NSObject.Type,
            appClass.responds(to: NSSelectorFromString("sharedApplication")),
            let app = appClass
                .perform(NSSelectorFromString("sharedApplication"))?
                .takeUnretainedValue() as? NSObject
        else {
            return false
        }

        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        guard app.responds(to: selector) else {
            return false
        }

        typealias OpenURLFunction = @convention(c) (
            AnyObject,
            Selector,
            NSURL,
            NSDictionary,
            AnyObject?
        ) -> Void

        let implementation = app.method(for: selector)
        let function = unsafeBitCast(implementation, to: OpenURLFunction.self)
        function(app, selector, url as NSURL, [:] as NSDictionary, nil)
        return true
    }

    private func completeExtensionRequest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

}
