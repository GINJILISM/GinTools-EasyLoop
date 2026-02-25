# iOS開発ガイド（Xcode / Codex連携）

このドキュメントは **「iPhone / iPadで確実にビルドと起動を通す」** ことを最優先に、
Flutter + Xcode での iOS 開発フローをまとめたものです。

## 0. 最優先ゴール

1. iPhone 実機で `Runner` がビルド・起動できる
2. iPad 実機で `Runner` がビルド・起動できる
3. その後に Share Extension / 書き出し再設計を段階的に導入する

## 0-1. 現在の重要課題（2026-02）

- 共有シートからの動画インポートは暫定導線を実装済みだが、実機で安定していない
- 直近の最優先は「共有シート → EasyLoop起動 → エディター画面で即編集開始」の再現性向上
- この課題は **今後の改善タスク** として継続管理する

---

## 1. 事前準備（Mac側）

- Xcode（安定版）をインストール
- Command Line Tools を選択
  - `xcode-select -p`
  - 必要なら `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- 初回セットアップ
  - `sudo xcodebuild -runFirstLaunch`
  - `sudo xcodebuild -license accept`
- CocoaPods
  - `sudo gem install cocoapods` もしくは `brew install cocoapods`
- Flutter
  - `flutter doctor -v`
  - `flutter precache --ios`

> Codex が Linux 環境で動いている場合、iOS ビルドそのものは Mac 側でのみ実行可能です。

---

## 2. Flutter側の基本手順

```bash
flutter clean
flutter pub get
cd ios && pod repo update && pod install && cd ..
flutter devices
```

- `flutter devices` で iPhone / iPad が見えることを確認
- 表示されない場合はケーブル、信頼設定、Developer Mode を再確認

---

## 3. Xcodeでのビルド手順（詳細）

## 3-1. ワークスペースを開く

- `ios/Runner.xcworkspace` を Xcode で開く（`.xcodeproj` ではなく `.xcworkspace`）

## 3-2. Signing 設定（Runnerターゲット）

1. `Runner` ターゲット → **Signing & Capabilities**
2. `Automatically manage signing` を有効化
3. Team を選択
4. Bundle Identifier を一意にする（例: `com.yourname.gintools.easyloop`）
5. `iOS Deployment Target` を実機要件に合わせる

## 3-3. 実機設定

- iPhone/iPad を接続
- 端末側で Developer Mode を ON
- 初回は「この開発者を信頼」を許可

## 3-4. ビルド対象の切り替え

- iPhone 実機を選択して Build（⌘B）
- iPad 実機を選択して Build（⌘B）
- 両方で成功するまで修正

## 3-5. よくある失敗と対処

- **No profiles for ...**
  - Team / Bundle Identifier / サイン設定を再確認
- **Pods 関連エラー**
  - `cd ios && pod install --repo-update`
- **Module not found / Flutter.framework**
  - `flutter clean && flutter pub get && cd ios && pod install`
- **実機が認識されない**
  - ケーブル、端末信頼、Developer Mode、Xcode の Devices and Simulators を確認

---

## 4. コマンドラインからのiOSビルド

### デバッグ

```bash
flutter build ios --debug
```

### リリース

```bash
flutter build ios --release
```

### IPA

```bash
flutter build ipa --release
```

> App Store 配布時は、証明書・プロビジョニング・App Store Connect 側設定を別途揃えること。

---

## 4-1. 2026-02-25 実測メモ（今回の検証で確定したこと）

今回、以下の順で **Simulator Debug ビルド成功** を確認済み:

```bash
flutter clean && flutter pub get
cd ios && pod install
flutter build ios --simulator
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator build
```

### 成功条件（今回の環境）

- `xcode-select -p` が `/Applications/Xcode.app/Contents/Developer` を指していること
- `pod` コマンドが導入済みであること（例: `brew install cocoapods`）
- `ios/Podfile` が存在し、`pod install` が完了していること

### 実運用での注意点

- `ios/Runner.xcworkspace` を使う（`Runner.xcodeproj` では Pod 連携が欠落しやすい）
- `flutter create --platforms=ios --overwrite .` は既存ファイルを広範囲に上書きするため原則避ける
- `Application not configured for iOS` が出たら、`ios/Podfile` の有無と `flutter pub get` 後の再生成状態を確認する
- `pod install` 後に Pods 側 warning（低い deployment target など）が出ても、即 build fail とは限らない（今回 `xcodebuild` は成功）


---

## 5. iPhone / iPad ビルド検証チェックリスト

各変更ごとに最低限以下を確認:

- [ ] iPhone 実機 Debug ビルド成功
- [ ] iPad 実機 Debug ビルド成功
- [ ] 起動後に Import 画面表示
- [ ] 動画1本を読み込み、編集画面へ遷移
- [ ] プレビュー再生ができる
- [ ] 書き出し導線でクラッシュしない（方式未確定の場合はガード表示）

リリース前追加チェック:

- [ ] `flutter build ios --release` 成功
- [ ] Xcode Archive 成功
- [ ] 実機で最低1回のスモークテスト（iPhone / iPad）

---

## Codex Cloud 共通ポリシー

- Cloud作業時の標準指示は `AGENT.md` を参照。
- 本リポジトリでは、Cloud上で `xcodebuild` / iOS Simulator は実行しない前提で品質チェックを進める。

---

## 6. Xcode と Codex の連携方法

Codex は設計・コード修正・差分提案を担当し、最終ビルド検証は Mac + Xcode で行う運用を推奨します。

### 推奨フロー

1. **Codex側**
   - 変更案作成、README/コード更新、テストコマンド提示
2. **Mac側（開発者）**
   - `git pull`
   - `flutter pub get`
   - `ios/Runner.xcworkspace` を開いて iPhone/iPad ビルド
3. **結果をCodexへ返す**
   - ビルドログ / エラー内容を貼る
4. **Codex側**
   - ログ解析して修正パッチを提案

### 連携時のポイント

- Xcode エラーは全文（最初のエラー行）を共有する
- 端末情報（iPhone/iPad、iOSバージョン）を共有する
- 署名エラーは Team/Bundle ID/Provisioning の状態を共有する

---

## 7. モバイル実装の懸念点（深掘り）

- **Share Extension の制約**
  - メモリ・実行時間が厳しいため、Extension 側で重い変換をしない
- **データ受け渡しの整合**
  - App Group の共有領域に置くファイルは TTL（削除期限）を決める
- **書き出しエンジンの段階移行**
  - いきなり全面置換せず、MP4→GIF→JPGの順に切替
- **端末差分**
  - SoC/メモリ差で処理時間が大きく変わるため、低スペック端末を必ず含める
- **バックグラウンド動作**
  - 中断時の再開仕様を先に決めないと、破損ファイルや二重実行を生みやすい

---

## 8. 段階実装タスク（慎重に進める前提）

1. Step 1: Runner 単体で iPhone/iPad ビルド安定化
2. Step 2: 共有シート取り込みの安定化（暫定導線の原因切り分け）
  - 共有元（写真/Files/他アプリ）別の再現条件を整理
  - コールドスタート/ウォームスタートの挙動差をログで可視化
  - 必要に応じて Share Extension + App Group 方式へ移行
3. Step 3: iOS書き出し方式の PoC 比較
4. Step 4: 方式確定後に本実装（進捗/キャンセル/失敗復帰）
5. Step 5: モバイル特化テストを拡張してリリース判定

> 無理に一括実装せず、**各Stepでビルド成功と実機確認を完了してから次へ進む**。
