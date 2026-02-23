# Loop Video Editor (Flutter)

Windows/macOS を主対象にした GUI ベースの動画ループ編集アプリです。  
動画をドロップまたは選択すると、直接トリミング編集画面へ遷移します。

## 実装方針

- UI は Flutter で共通実装（Windows/macOS/iOS で同一レイアウト）
- 動画処理は FFmpeg CLI ベース（トリム、逆再生、連結、MP4 出力）
- OS 差分はサービス層で吸収
  - Windows: 起動引数で受け取り
  - macOS: `openFiles` -> MethodChannel で受け取り
- 状態管理は `Provider + ChangeNotifier`
  - 理由: MVP で依存を増やさず、責務を分離しやすい

## 現在の実装状況

### Phase 1 (MVP)

- ファイル選択インポート
- デスクトップ D&D インポート
- 編集画面（プレビュー、trim start/end、ループ形式選択）
- MP4 書き出し（通常ループ / ピンポンループ）
- ループ回数指定（デフォルト 4）
- 書き出し進捗表示
- 編集中の新規 D&D 置換（確認ダイアログ付き）

### 追加改善（今回反映）

- タイムライン倍率 `1.0` を「画面幅 fit」基準に統一
- サムネイルをタイル表示（`BoxFit.contain`、切れない表示）
- サムネイル生成を軽量化（`scale=96:-2`、低品質 JPEG）
- ズーム変更時のみサムネイル密度を再生成
- ピンポン選択時のプレビュー往復（擬似ピンポン）

### Phase 2（未実装）

- GIF 書き出し本実装（`palettegen/paletteuse`）
- iOS Share Extension
- macOS/Windows 配布時の本番向け関連付け運用（証明書・署名手順の整備）

## UI仕様

- 日本語 UI
- 上段: 自動再生プレビュー
- 下段: タイムライン（サムネイル帯 + start/end ハンドル + 再生ヘッド + 秒目盛り）
- ズームスライダーでタイムライン密度を調整
- 書き出し設定は最小限（形式 / ループ回数 / 実行）

## 起動導線

1. アプリ起動 -> 動画をドロップ or ファイル選択 -> 直接編集画面へ
2. 編集中でも動画をウィンドウへドロップ可能
   - 確認ダイアログ承認後に編集対象を差し替え

## OS差分

### Windows

- 起動引数で初期ファイルを受け取り
- MSIX の `file_extension` で関連付け宣言
- 対応拡張子: `mp4/mov/m4v/avi/mkv/webm`

### macOS

- `Info.plist` の `CFBundleDocumentTypes` で関連付け宣言
- `AppDelegate.application(_:openFiles:)` で受け取り
- MethodChannel: `com.gintoolflutter.launch/open_file`

### iOS

- 同一 UI で動作
- FFmpeg CLI 書き出しは現状無効（制約表示）
- Share Extension は Phase 2

## 依存パッケージと採用理由

- `provider`: MVP 向けに軽量で保守しやすい状態管理
- `media_kit` / `media_kit_video`: クロスプラットフォーム動画再生
- `desktop_drop`: デスクトップ D&D
- `file_picker`: ファイル選択・保存先選択
- `path` / `path_provider`: パス処理・作業ディレクトリ管理
- `open_filex`: 出力先の導線
- `crypto`: サムネイルキャッシュキー生成
- `msix` (dev): Windows 配布パッケージ作成

## FFmpeg仕様

### 通常ループ（MP4）

1. `start-end` をトリム
2. トリム結果を指定回数 `concat`
3. MP4 出力

### ピンポンループ（MP4）

1. `start-end` をトリム
2. 逆再生クリップ生成（境界重複回避: `trim=start_frame=1`）
3. 正再生 + 逆再生を 1 セットとして `concat`

### 音声方針

- 初期実装はミュート出力（`-an`）
- 逆再生時の音声整合は Phase 2 で設計

## セットアップ

1. Flutter 環境確認
   - `flutter doctor`
2. 依存取得
   - `flutter pub get`
3. FFmpeg をインストール
   - Windows: `winget install Gyan.FFmpeg`
   - macOS: `brew install ffmpeg`
4. 動作確認
   - `ffmpeg -version`
   - `ffprobe -version`

## 実行手順（GUI）

- Windows: `flutter run -d windows`
- macOS: `flutter run -d macos`

起動後は GUI で以下を操作:

- ウィンドウに動画をドロップ
- または「動画を選択」

## ビルド手順

### Windows exe

- `flutter build windows`

### Windows MSIX

- `flutter pub run msix:create --certificate-path <pfx> --certificate-password <password>`
- 詳細は `tool/msix/README.md`

### macOS

- `flutter build macos`
- 配布は `.app` を DMG 化して運用

## 主要ディレクトリ構成

```text
lib/
  main.dart
  src/
    app.dart
    models/
    services/
      file_import_service.dart
      launch_file_service.dart
      timeline_thumbnail_service.dart
      ffmpeg_cli_video_processor.dart
      video_processor.dart
    state/
      app_controller.dart
      editor_controller.dart
    ui/
      screens/
        root_screen.dart
        import_screen.dart
        editor_screen.dart
      widgets/
        editor_shell.dart
        preview_stage.dart
        replace_input_dialog.dart
        trim_timeline.dart
        timeline_zoom_bar.dart
macos/Runner/
  AppDelegate.swift
  Info.plist
tool/msix/
  README.md
```

## 既知の制約

- GIF は UI 選択のみ（処理は未実装）
- iOS は FFmpeg CLI 書き出し未対応
- サムネイルは応答性優先の低解像度

## 難所メモ

- macOS の `openFiles` は Flutter 初期化前に届く場合があるため、ネイティブ側で一時キュー化
- ピンポンプレビューはプレイヤーのネイティブ逆再生を使わず、seek 反転で擬似実装
- タイムラインの fit 基準とズーム再生成を分離して、操作時の体感遅延を抑制

## テスト

- 静的解析: `flutter analyze`
- テスト: `flutter test`

## 今後のTODO

1. GIF 本実装（`palettegen` / `paletteuse`）
2. iOS Share Extension
3. iOS 向け動画処理方式の再設計（例: `ffmpeg_kit` 検討）
4. 配布時の関連付け運用（証明書/署名/更新戦略）
