# GinTools-EasyLoop (Flutter)

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
- Windows/macOS のファイル関連付け経由起動（受け取り実装）
- Windows MSIX 開発用インストールスクリプト

### 未実装 / 制約（残タスク）

1. iOS Share Extension（共有シート受け取り）
2. iOS の動画書き出し実装（FFmpeg CLI 依存を再設計）
3. GIF品質パラメータのUI化（fps / scale / palette戦略）
4. Windows「右クリック直下の独自メニュー」
: 現在は「このアプリで開く」配下。直下表示は別途 COM 拡張DLLが必要。
5. 自動E2E整備（Windows/macOSの配布導線検証）

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

## ビルド

### Windows

- EXE: `flutter build windows`
- MSIX: `flutter pub run msix:create --certificate-path <pfx> --certificate-password <password>`

開発用（証明書登録 + インストール）:

- 管理者 PowerShell で `tool/msix/install_dev_msix.ps1` を実行

### macOS

- `flutter build macos`

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

## 今後の進め方（実装ロードマップ）

1. iOS書き出し方式の確定（`ffmpeg_kit` 含む技術検証）
2. GIF品質プリセットUI
3. 配布運用ドキュメント完成（証明書更新、バージョニング）
4. CIで `analyze/test/build` 自動化

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
