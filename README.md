# GinTools-EasyLoop (Flutter)
Simple cross-platform loop video editor for Windows/macOS/iOS.


Windows/macOS を主対象にした GUI ベースのループ動画編集アプリです。  
動画をドロップまたは選択すると、直接トリミング編集画面へ遷移します。

## 現在の実装状況

### 実装済み（Phase 1 + 一部Phase 2）

- ファイル選択インポート
- デスクトップ D&D インポート
- 編集画面（プレビュー / start-end トリム / 通常ループ / ピンポン）
- プレビュー上の再生トランスポート（再生・停止・移動・境界設定）
- タイムラインズーム、スクラブ、横パン
- 編集中の新規D&D置換
- MP4書き出し（通常/ピンポン、回数指定、進捗表示）
- GIF書き出し（1サイクル生成 + `-loop 0`）
- 現在フレームのJPG書き出し
- モバイルUI最適化（ボタン縮小/横並び、モバイル向けヘッダー簡略化）
- モバイルタイムライン操作（2本指ピンチズーム/2本指スライドパン）
- モバイル保存先導線（写真ライブラリ保存時の「保存先を開く」導線）
- Windows/macOS のファイル関連付け経由起動（受け取り実装）
- iOS 共有シート連携（Share Extension + App Group + URL Scheme）
   - 共有シートで `EasyLoop` を選択すると、投稿画面なしで本体へ直接遷移
   - 本体未起動時/起動済み時の双方で共有動画を編集画面へ引き渡し
- Windows MSIX 開発用インストールスクリプト

## Liquid Glass 実装メモ（Windows安定化）

### タイムライン Liquid 範囲オーバーレイ（2026-03 追加）

- トリム選択範囲（start~end）に、角丸長方形の透明 Liquid Glass オーバーレイを重ねる。
- レイヤー順は `サムネイル -> Liquid範囲 -> マーカー/Playhead/TrimHandle`。
- 外側減光は単純な左右矩形ではなく、角丸穴あきマスク（CustomPainter）で処理し、Liquid形状と一致させる。
- `set start / set end` で位置が飛ぶとき、ハンドルと Liquid 範囲を同じ慣性オフセットで動かし、見た目のズレを防ぐ。
- Liquid の glow は `BoxShadow` + `GlassGlow`（非Windows）で付与。Windows は安定性優先で控えめ設定。

#### 主な調整先（Single Source of Truth）

- `lib/src/ui/liquid_glass/liquid_glass_refs.dart`
  - `timelineSelectionLayerSettings` / `timelineSelectionLayerSettingsWindows`
  - `timelineSelectionGlass*`（inset/radius/border/fill）
  - `timelineSelectionOutsideDimColor`
  - `timelineSelectionGlowColor`, `timelineSelectionGlowRadius`, `timelineSelectionGlowSpread`
  - `timelineTrimHandleInertia*`（duration/min-max offset/pulse）

#### 実装ファイル

- `lib/src/ui/widgets/trim_timeline.dart`
  - `InteractiveViewer` をサムネイル側に適用
  - `_buildTrimRangeLiquidOverlay`
  - `_buildOutsideDimOverlay` + `_OutsideSelectionDimPainter`
  - `visualTrimStart/End` ベースで overlay / mask / handle を同期

### 躓きポイント（再発しやすい実装矛盾）

1. `LiquidGlass` のスコープ不足  
   - `LiquidGlass.grouped` は必ず `LiquidGlassLayer` + `LiquidGlassBlendGroup` 配下で使う。  
   - 単体ボタンは `LiquidGlass.withOwnLayer` を使う（Layerなしで `LiquidGlass` を直接置かない）。
2. grouped / non-grouped の混在  
   - 同じまとまりで「くっつき」を狙う要素は grouped で統一する。  
   - くっつかせない要素は `withOwnLayer` 側に分離する。
3. Windowsでの過剰エフェクト  
   - `thickness/blur/stretch/interactionScale` を他OSと同じ強さにすると、描画負荷よりも実装相性で不安定化しやすい。  
   - Windows専用値は `lib/src/ui/liquid_glass/liquid_glass_refs.dart` の `*Windows` 定数で管理する。
4. 動画プレビューまわりの競合  
   - `media_kit_video` の `Video` は `fill` を明示し、余白色をアプリ背景と揃える。  
   - プレビューで問題が出た場合は、`InteractiveViewer` や過剰アニメーションを先に疑う。
5. 変更後の確認不足  
   - 液体表現を触った後は最低限 `flutter analyze` + 関連 `flutter test` を実行する。  
   - 特に `Editor` 遷移直後（Import -> Editor）を実機で確認する。

### デバッグ順序（フリーズ時）

1. 直近で追加した `LiquidGlass` ノードが `Layer` 配下か確認  
2. grouped 要素が `LiquidGlassBlendGroup` 内か確認  
3. Windows専用パラメータを一段弱める（`blur/stretch` 優先）  
4. それでも不安定なら、該当要素だけ一時的に `withOwnLayer` の単体表現に戻す

## UIデザインルール（.pen反映の実装規約）

1. トークン一元管理  
   - 色・Liquidパラメータは `LiquidGlassRefs` に集約し、画面側で直書きしない。
2. レイアウト優先順位  
   - `Preview / Timeline / Control` を別グループで扱う。  
   - `Timeline` と `Control` は固定高、余剰高さは `Preview` に優先配分する。
3. プレビュー余白の見え方  
   - 動画アスペクト外余白は黒帯にしない。  
   - `Video.fill` と外側背景を同系色（原則 `editorBgBase`）に揃える。
4. .pen注記の扱い  
   - `.pen` の「Implementation Notes」は設計メモであり、ランタイムUIには表示しない。
5. 新規Liquid UI追加時  
   - 既存の共通部品（`InteractiveLiquidGlassIconButton` / `LiquidGlassActionButton`）を優先利用する。  
   - 個別実装が必要でも、最終的に `refs` 管理へ寄せる。

### 未実装 / 制約（残タスク）

1. GIF品質パラメータのUI化（fps / scale / palette戦略）
2. Windows「右クリック直下の独自メニュー」
: 現在は「このアプリで開く」配下。直下表示は別途 COM 拡張DLLが必要。
3. 自動E2E整備（Windows/macOSの配布導線検証）

## 調整余地（チューニング候補）

### パフォーマンス

- 長尺動画時のサムネイル生成をさらに分割・遅延化
- トリム操作中の `setState` 範囲を局所化
- FFmpegプロセス起動回数削減（一時ファイル最適化）

### UX

- 初心者向けプリセット（SNS用解像度/フレームレート）
- 書き出し結果の履歴一覧
- エラー文言のOS別ガイダンス強化

### 品質

- widget test 追加（運搬UI、書き出しパネル条件分岐）
- 回帰用サンプル動画セットの固定化
- 失敗ケース（権限不足/空き容量不足）テスト追加

## OS差分方針

- UI は Flutter 共通
- 差分はサービス層で吸収
  - Windows: 起動引数受け取り
  - macOS: `openFiles` + MethodChannel
  - iOS: 現状は一部機能制限あり

## 依存パッケージ（主なもの）

- `provider`: シンプルな状態管理
- `media_kit`, `media_kit_video`: クロスプラットフォーム動画再生
- `desktop_drop`: デスクトップD&D
- `file_picker`: ファイル選択/保存先選択
- `open_filex`: 出力先導線
- `msix` (dev): Windows配布パッケージ作成

## セットアップ

1. Flutter確認: `flutter doctor`
2. 依存取得: `flutter pub get`
3. FFmpeg導入
- Windows: `winget install Gyan.FFmpeg`
- macOS: `brew install ffmpeg`

## 実行

- Windows: `flutter run -d windows`
- macOS: `flutter run -d macos`
- iOS（シミュレータ）: `flutter run -d ios`
- iOS（実機）: 端末接続後 `flutter devices` で ID を確認し、`flutter run -d <device-id>`

> iOS 実機で初回実行する場合は、`ios/Runner.xcworkspace` を Xcode で開き、
> Signing & Capabilities の Team / Bundle Identifier を設定してください。

## ビルド

### Windows

- EXE: `flutter build windows`
- MSIX: `flutter pub run msix:create --certificate-path <pfx> --certificate-password <password>`

開発用（証明書登録 + インストール）:

- 管理者 PowerShell で `tool/msix/install_dev_msix.ps1` を実行

### macOS

- `flutter build macos`

### iOS

- Debugビルド: `flutter build ios --debug`
- Releaseビルド: `flutter build ios --release`
- IPA（配布用）: `flutter build ipa --release`

補足:
- iOS/Android は `ffmpeg_kit_flutter_new_gpl` による組み込みFFmpeg実行へ切り替え済み（CLIのPATH依存を解消）。
- Share Extension 追加時は `Runner` とは別ターゲット（Extension）の署名設定も必要になります。

## iOS開発ドキュメント

- 詳細は `readme_iOSDev.md` を参照（Xcodeでの実機/シミュレータ手順、Codex連携、ビルド検証チェックリスト）。

## 既知の課題（2026-02時点）

- 実機ビルド時は空き容量不足で失敗しやすいため、`DerivedData` の定期クリーンを推奨

## 主要ディレクトリ

```text
lib/
  src/
    models/
    services/
    state/
    ui/
      screens/
      widgets/
test/
tool/msix/
windows/
macos/
ios/
```

## 次にやること（iOS対応ゴールに向けて）

### 1) iOS の動画書き出し方式（実装済み方針）

- 現行: `ffmpeg_kit_flutter_new_gpl` を採用してモバイルPATH依存を解消（将来候補としてAVFoundation併用を評価）
- 端末性能・発熱・処理時間・バイナリサイズを含む評価軸を先に固定
- 進捗通知 / キャンセル / エラーハンドリングのAPIを `VideoProcessor` 抽象で統一
- MP4/GIF/JPG は同一の書き出し手順を維持し、iOS/Androidではffmpeg_kit実行・デスクトップではCLI実行の分岐で機能差を抑える

### 2) モバイル向けUX・運用整備

- 権限（写真ライブラリ、ファイルアクセス）拒否時の再試行導線を追加
- バックグラウンド遷移時の処理継続/中断ポリシーを決定
- クラッシュ収集・ログ方針（iOS実機中心）を運用に組み込む

## モバイル実装の懸念点

- **拡張と本体の分離**: Share Extension はメモリ・実行時間制限が厳しく、重処理を持たせにくい
- **ファイル受け渡し**: 一時ファイルのライフサイクル管理が曖昧だと、起動タイミングで読み込み失敗しやすい
- **コーデック差異**: 端末/OSで対応コーデックや挙動が微妙に異なる
- **長時間書き出し**: 熱・バッテリー制約で処理速度が不安定になる
- **ビルド/署名複雑化**: Runner + Extension の証明書・プロビジョニング整合が崩れやすい
- **プラグイン互換性**: Flutterプラグインが Extension ターゲット非対応のケースがある

## モバイル向け特別テスト項目

1. **共有シート受け取りE2E**
   - 写真アプリ/Files/他アプリから共有 → 本体起動 → 編集画面遷移まで
2. **コールドスタート/ウォームスタート差分**
   - 本体未起動時・起動済み時で同じ入力が同じ結果になるか
3. **大容量・長尺入力**
   - 4K / 高fps / 長尺での読み込み・書き出し成功率、処理時間、メモリ
4. **書き出し中断系**
   - 途中キャンセル、アプリバックグラウンド遷移、低電力モード時の挙動
5. **容量・権限エラー**
   - 空き容量不足、フォトライブラリアクセス拒否、保存先不可時のUI/復帰
6. **端末マトリクス**
   - 低RAM端末〜最新端末、iOS複数バージョンでの再現性確認
7. **成果物妥当性**
   - ループ境界、音声有無、回転情報、メタデータ（向き/時間）の維持確認

## 今後の進め方（実装ロードマップ）

1. iOS書き出し方式のPoC（2案以上）と比較結果確定（※ いきなり本実装へ進まず、1機能ずつ段階導入して安定性を確認）
3. 配布運用ドキュメント完成（証明書更新、バージョニング）（※ Extension追加後の署名手順差分も反映）
4. CIで `analyze/test/build` 自動化（※ iOS実機テストは手動ゲートを残しつつ徐々に自動化）

## Git初心者向け（このリポジトリ運用）

### 日常コマンド

1. 状態確認: `git status`
2. 変更追加: `git add -A`
3. コミット: `git commit -m "message"`
4. 取得: `git pull --rebase origin main`
5. 反映: `git push origin main`

### 事故を減らす基本

- いきなり `git reset --hard` は使わない
- こまめにコミットする
- push前に `flutter analyze` を通す

## 今日のゴール: Codexでリモート管理可能にする手順

1. GitHub に `GinTools-EasyLoop` リポジトリを作成
2. このローカルに `origin` を設定
3. `main` ブランチを初回 push
4. 以後は Codex から `pull/push` を実行可能

補足:
- 現在 `gh` CLI は未導入環境のため、リモート作成はブラウザ経由が最短です。
- リポジトリ作成後に URL が分かれば、残り（remote設定/push）はこちらで実行します。
