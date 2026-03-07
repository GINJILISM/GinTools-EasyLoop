class AppStrings {
  AppStrings._();

  // Import screen
  static const fileAppVideoPickerTitle = 'ファイルアプリから動画を選択';
  static const importScreenTitle = '編集する動画を選択';
  static const importScreenDescription = 'ここにドロップするか、ファイル/ライブラリから開いてください。';
  static const openFromFile = 'ファイルから開く';
  static const openFromLibrary = 'ライブラリから開く';
  static const desktopDragAndDropHint = 'Desktop: ドラッグ&ドロップ対応';

  // Validation & generic
  static const videoNotSelected = '動画ファイルが選択されていません。';
  static String unsupportedFileFormat(String extensions) =>
      '未対応のファイル形式です。対応形式: $extensions';
  static const pickVideoFileDialogTitle = '動画ファイルを選択';

  // Editor shell / shared
  static const selectFromLibrary = 'ライブラリから選択';
  static const selectFromFile = 'ファイルから選択';
  static String editingTitle(String title) => 'Editing: $title';
  static const addVideo = '動画を追加';
  static const selectImportMethod = '読み込み方法を選択';
  static const dropToReplaceVideo = 'ここにドロップして動画を置き換え';

  // Replace dialog
  static const replaceVideoTitle = '別の動画に切り替えますか？';
  static const replaceVideoDescription = '現在の編集中セッションは新しい動画に置き換えられます。';
  static const cancel = 'キャンセル';
  static const replace = '切り替える';

  // Loop & transport
  static const loopOff = 'ループオフ';
  static const normalLoop = '通常ループ';
  static const pingPongLoop = 'ピンポンループ';
  static const setCurrentAsStart = '現在位置を開始点に設定';
  static const jumpToStart = '開始点へ移動';
  static const stepBackOneFrame = '1フレーム戻る';
  static const pause = '一時停止';
  static const play = '再生';
  static const stepForwardOneFrame = '1フレーム進む';
  static const jumpToEnd = '終了点へ移動';
  static const setCurrentAsEnd = '現在位置を終了点に設定';

  // Model labels
  static const loopModeForwardLabel = '→ 通常ループ';
  static const loopModePingPongLabel = '←→ ピンポン';
  static const gifQualityLow = '低 (約200px)';
  static const gifQualityMedium = '中 (50%解像度)';
  static const gifQualityHigh = '高 (100%解像度)';
  static String gifFpsLabel(int value) => '$value FPS';

  // Controller
  static const exportUnavailable = '書き出し可能な状態ではありません。';
  static const exportStarting = '書き出しを開始しています...';
  static const exportCompleted = '書き出しが完了しました。';
  static String unexpectedExportError(Object error) => '書き出し中に予期しないエラーが発生しました: $error';
  static const frameExportUnavailable = '現在の状態ではフレーム書き出しできません。';
  static String unexpectedFrameExportError(Object error) => 'フレーム書き出し中に予期しないエラーが発生しました: $error';

  // Editor screen
  static const cannotSwitchVideoWhileExporting = '書き出し中は入力動画を切り替えできません。';
  static String failedToLoadVideo(Object error) => '動画の読み込みに失敗しました: $error';
  static const exportDoneSnackbar = '書き出しが完了しました。';
  static String frameExportDone(String framePath) => 'フレーム画像を書き出しました: $framePath';
  static const saveFailed = '保存に失敗しました。';
  static const frameSavedToPhotoLibrary = 'フレーム画像をフォトライブラリに保存しました。';
  static String failedToSavePhotoLibrary(Object error) => 'フォトライブラリ保存に失敗しました: $error';
  static const openOutputDestination = '保存先を開く';
  static const failedToOpenPhotoLibraryApp = 'フォトライブラリアプリを開けませんでした。';
  static const setExportPath = '書き出し先パスを設定してください。';
  static const loadingVideoFromICloud = 'iCloud から動画を読み込み中...';
  static const timelineGestureHint = 'タイムライン: 2本指ピンチで拡大縮小 / 2本指スライドで左右スクロール';
  static const exportSettingsTitle = '書き出し設定';
  static const exportFormat = '書き出し形式';
  static const loopCount = 'ループ回数';
  static String loopCountValue(int count) => '${count}回';
  static const gifQuality = 'GIF品質';
  static const gifFps = 'GIF FPS';
  static const fileNameTemplate = '書き出しファイル名テンプレート（拡張子なし）';
  static const fileNameTemplateHelp =
      '使用できる変数: {looptype}, {filename}\n例: {looptype}_{filename}\n出力例: loop_sample.mp4 / pingpongLoop_sample.gif / snapshot_sample.jpg';
  static const imageExportPath = '画像書き出しパス';
  static const pickImageExportFolder = '画像書き出しフォルダを選択';
  static const videoExportPath = '動画書き出しパス';
  static const pickVideoExportFolder = '動画書き出しフォルダを選択';
  static const gifExportPath = 'GIF書き出しパス';
  static const pickGifExportFolder = 'GIF書き出しフォルダを選択';
  static const saveToPhotoLibraryDirectly = 'フォトライブラリに直接保存';
  static const enableLiquidGlassUi = 'Liquid Glass UI を有効化';
  static const liquidGlassPerformanceHint = '重い場合は OFF にしてください';
  static const close = '閉じる';
  static const enterExportPath = '書き出し先パスを入力';
  static const exportPathNotNeededForPhotoLibrary = 'フォトライブラリ保存時は不要';
  static const select = '選択';
  static const frameExport = 'フレーム書き出し';
  static const exportCurrentFrameImage = 'このフレームを画像書き出し';
  static const export = '書き出し';
  static const exportSettingsTooltip = '書き出し設定';
  static const frameImageExporting = 'フレーム画像を書き出し中...';
  static const outputToPhotoLibrary = '出力先: フォトライブラリ';
  static String outputToPath(String path) => '出力先: $path';
  static const frameOutputToPhotoLibrary = '画像出力先: フォトライブラリ';
  static String frameOutputToPath(String path) => '画像出力先: $path';


  static const failedToGetVideoDuration = '動画の長さを取得できませんでした。';
  static const failedToParseVideoDuration = '動画長さの解析に失敗しました。ffprobeの設定を確認してください。';
  static const invalidTrimRange = '開始点と終了点の範囲が不正です。';
  static const invalidLoopCount = 'ループ回数は1以上で指定してください。';
  static const trimming = 'トリミング中...';
  static const generatingGifPalette = 'GIFパレット生成中...';
  static const gifEncoding = 'GIFエンコード中...';
  static const exportDone = '書き出し完了';
  static const concatenating = '連結中...';
  static const generatingReverseClip = '逆再生クリップ生成中...';
  static const pingPongConcatenating = 'ピンポン連結中...';
  static const gifSingleCycleGenerating = 'GIF 1サイクル生成中...';
  static const ffmpegNotFoundInPath = 'FFmpegが見つかりません。PATHにffmpeg/ffprobeを追加してください。';
  static String inputVideoNotFound(String path) => '入力動画が見つかりません: $path';
  static String failedToCopyInputVideo(String message) => '入力動画の一時コピーに失敗しました: $message';
  static const ffmpegExecutionFailed = 'FFmpegの実行に失敗しました。';
  static const emptyInputVideoPath = '入力動画パスが空です。';
  static String unsupportedInputPathFormat(String path) => '未対応の入力パス形式です: $path';
  static String failedToParseInputPath(String path) => '入力動画パスの解析に失敗しました: $path';
  static const failedToGetDetailedLog = '詳細ログを取得できませんでした。';
  static const failedToStartFfmpeg = 'ffmpeg/ffprobe の起動に失敗しました。';
  static const ffmpegNotInstalled = 'ffmpeg/ffprobe が見つかりません。インストール後に再実行してください。';

  static const timelineZoom = 'タイムラインズーム';
  static const thumbnailLoading = 'サムネイル読み込み中...';
  static String savedToPhotoLibrary(String formatLabel) => '$formatLabel をフォトライブラリに保存しました。';
}

