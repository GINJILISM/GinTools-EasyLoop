# LLM Agent String Policy (GinTools-EasyLoop)

このドキュメントは、LLMエージェント（Codex等）が本リポジトリで文言を追加・変更する際の必須ルールです。

## 目的

- UI上の文言変更を安全・迅速に行えるようにする
- 文言の散在（ハードコード）を防ぎ、保守性を上げる
- 将来の多言語化・A/Bテキスト差し替えに備える

## Single Source of Truth

- UI表示文言の管理元は **`lib/src/ui/app_strings.dart`** とする
- 画面・ウィジェット・UIに表示されるユーザー向けエラーメッセージは、原則 `AppStrings` を参照する

## 必須ルール

1. 新規にユーザー表示テキストを追加する場合、まず `AppStrings` に定義する
2. `Text('...')` / `tooltip: '...'` / `labelText: '...'` などへ文字列リテラルを直接書かない
3. 文字列が動的な場合は `AppStrings` にメソッドを追加して組み立てる
4. 既存ハードコード箇所を触る変更では、可能な限り `AppStrings` 参照に寄せる
5. テストコードの文言は可読性を優先し、必須ではない（ただしUI仕様文言の重複定義は避ける）

## 実装パターン

### 固定文言

```dart
// app_strings.dart
static const exportSettingsTitle = '書き出し設定';

// 呼び出し側
title: const Text(AppStrings.exportSettingsTitle)
```

### 動的文言

```dart
// app_strings.dart
static String outputToPath(String path) => '出力先: $path';

// 呼び出し側
Text(AppStrings.outputToPath(controller.lastOutputPath!))
```

## レビュー時チェックポイント

- 新規のUI表示テキストが `app_strings.dart` に定義されているか
- 画面側に不要な文字列リテラルが増えていないか
- 似た文言が重複定義されていないか
- 命名が機能ベースで明確か（例: `exportSettingsTitle`, `failedToLoadVideo`）

## 例外運用

以下は例外として許容:

- Flutterの `Key(...)` 用文字列
- ログ・デバッグ専用文字列（ユーザー非表示）
- 外部仕様に固定された識別子（拡張子、プロトコル名など）

ただし、例外でも「将来UI表示に使う可能性がある文字列」は `AppStrings` へ寄せること。
