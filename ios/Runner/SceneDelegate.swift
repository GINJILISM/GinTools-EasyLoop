import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)

    let paths = URLContexts
      .map { $0.url }
      .compactMap { SharedMediaBridge.normalizeIncomingUrl($0)?.path }

    SharedMediaBridge.post(paths: paths)
  }
}
