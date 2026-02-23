# Windows MSIX Build & File Association

## 前提

- Windows 10/11
- Flutter SDK インストール済み
- `flutter pub get` 実行済み
- 署名用の `.pfx` 証明書を用意済み

## ビルド手順

1. Windows バイナリを作成
   - `flutter build windows --release`
2. MSIX を作成
   - `flutter pub run msix:create --certificate-path <path-to-pfx> --certificate-password <password>`

### 開発用インストール（証明書エラー回避）

管理者 PowerShell で以下を実行してください。

- `.\tool\msix\install_dev_msix.ps1`

このスクリプトは `.cer` を `LocalMachine\Root` / `LocalMachine\TrustedPeople` に登録し、
`EasyLoop.msix` をインストールします。

## 関連付け

`pubspec.yaml` の `msix_config.file_extension` で以下を宣言しています。

- `.mp4`
- `.mov`
- `.m4v`
- `.avi`
- `.mkv`
- `.webm`

インストール後、これらの動画ファイルを右クリックして「このアプリで開く > GinTools-EasyLoop」を選ぶと、
アプリ起動時に対象ファイルが引数として渡され、編集画面へ直接遷移します。

## 注意

- 本番配布では信頼された証明書を使用してください。
- 関連付けの反映には再インストールやユーザー側の既定アプリ設定が必要な場合があります。
