import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    _ = handle(urlContexts: connectionOptions.urlContexts)
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    let consumed = handle(urlContexts: URLContexts)
    if !consumed {
      super.scene(scene, openURLContexts: URLContexts)
    }
  }

  @discardableResult
  private func handle(urlContexts: Set<UIOpenURLContext>) -> Bool {
    var consumedAny = false
    for context in urlContexts where SharedMediaBridge.consumeIncomingUrl(context.url) {
      consumedAny = true
    }
    return consumedAny
  }
}
