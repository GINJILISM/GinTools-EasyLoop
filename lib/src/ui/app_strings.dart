class AppStrings {
  AppStrings._();

    static const appName = 'イージーループ';

  // Import screen
  static const fileAppVideoPickerTitle = '選択';
  static const importScreenTitle = 'インポート';
  static const openFromFile = 'ファイルから';
  static const openFromLibrary = 'フォトライブラリから';
  static const desktopDragAndDropHint = 'Desktop: ドラッグ&ドロップ対応 (フォトライブラリはモバイル用)';

  // Validation & generic
  static const videoNotSelected = 'ムービーが選択されていない・・・';
  static String unsupportedFileFormat(String extensions) =>
      '未対応のファイル形式。対応形式: $extensions';
  static const pickVideoFileDialogTitle = 'ムービーを選択';

  // Editor shell / shared
  static const selectFromLibrary = 'ライブラリから';
  static const selectFromFile = 'ファイルから';
  static String editingTitle(String title) => 'Editing: $title';
  static const addVideo = 'ムービーを追加';
  static const selectImportMethod = '読み込み方法を選択';
  static const dropToReplaceVideo = 'ドロップ・・・ドロップ・・・ドロップ・・・';

  // Replace dialog
  static const replaceVideoTitle = 'このムービーをインポートする？';
  static const replaceVideoDescription = '現在の編集中セッションは新しいムービーに置き換えられる';
  static const cancel = 'キャンセル';
  static const replace = 'キリカエル';

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
  static const exportUnavailable = '書き出し可能な状態ではない...';
  static const exportStarting = '書き出しを開始している...';
  static const exportCompleted = '書き出しが完了した！';
  static String unexpectedExportError(Object error) =>
      '書き出し中に予期しないエラーが発生した: $error';
  static String exportUnavailableForFormat(String formatLabel) =>
      '$formatLabelを書き出し可能な状態ではない...';
  static String exportStartingForFormat(String formatLabel) =>
      '$formatLabel書き出しを開始している...';
  static String exportCompletedForFormat(String formatLabel) =>
      '$formatLabel書き出しが完了した！';
  static String unexpectedExportErrorForFormat(
    String formatLabel,
    Object error,
  ) =>
      '$formatLabel書き出し中に予期しないエラーが発生した: $error';
  static const frameExportUnavailable = '現在の状態ではフレーム書き出しできません。';
  static String unexpectedFrameExportError(Object error) =>
      'フレーム書き出し中に予期しないエラーが発生した: $error';

  // Editor screen
  static const cannotSwitchVideoWhileExporting = '書き出し中は入力ムービーを切り替えできない！';
  static String failedToLoadVideo(Object error) => 'ムービーの読み込みに失敗しました: $error';
  static const exportDoneSnackbar = '書き出しが完了した！';
  static String exportDoneSnackbarForFormat(String formatLabel) =>
      '$formatLabelの書き出しが完了した！';
  static const captureSaved = 'キャプチャをエクスポート！';
  static const movieSaved = 'ムービーをエクスポート！';
  static const gifSaved = 'ジフをエクスポート！';
  static const saveFailed = '保存に失敗した..';
  static const frameSavedToPhotoLibrary = captureSaved;
  static String failedToSavePhotoLibrary(Object error) =>
      'フォトライブラリ保存に失敗した...: $error';
  static const openOutputDestination = '保存先を開く';
  static const failedToOpenPhotoLibraryApp = 'フォトライブラリアプリを開けなかった。';
  static const setExportPath = '書き出し先パスを設定しよう！';
  static String setExportPathForTarget(String targetLabel) =>
      '$targetLabel書き出し先パスを設定しよう！';
  static const loadingVideoFromICloud = 'iCloud からムービーを読み込み中...';
  static const exportSettingsTitle = 'カキダシ セッティング';
  static const exportFormat = '書き出し形式';
  static const loopCount = 'ループ回数';
  static String loopCountValue(int count) => '$count回';
  static const gifQuality = 'GIF品質';
  static const gifFps = 'GIF FPS';
  static const fileNameTemplate = '書き出しファイル名テンプレート（拡張子なし）';
  static const fileNameTemplateHelp =
      '使用できる変数: {looptype}, {filename}\n例: {looptype}_{filename}\n出力例: loop_sample.mp4 / pingpongLoop_sample.gif / snapshot_sample.jpg';
  static String fileNameTemplateHelpForFormat(String extension) =>
      '使用できる変数: {looptype}, {filename}\n'
      '例: {looptype}_{filename}\n'
      '出力例: loop_sample.$extension / pingpongLoop_sample.$extension / snapshot_sample.jpg';
  static const imageExportPath = '画像書き出しパス';
  static const pickImageExportFolder = '画像書き出しフォルダを選択';
  static const videoExportPath = 'ムービー書き出しパス';
  static const pickVideoExportFolder = 'ムービー書き出しフォルダを選択';
  static const mp4ExportPath = 'MP4書き出しパス';
  static const pickMp4ExportFolder = 'MP4書き出しフォルダを選択';
  static const gifExportPath = 'GIF書き出しパス';
  static const pickGifExportFolder = 'GIF書き出しフォルダを選択';
  static const saveToPhotoLibraryDirectly = 'フォトライブラリに直接保存';
  static const enableLiquidGlassUi = 'Liquid Glass(風) UI ';
  static const close = 'とじる';
  static const enterExportPath = '書き出し先パスを入力';
  static const exportPathNotNeededForPhotoLibrary = 'フォトライブラリ保存時は不要';
  static const select = '選択';
  static const frameExport = 'キャプチャ';
  static const exportCurrentFrameImage = 'キャプチャ';
  static const export = '書き出し';
  static const exportMp4 = 'ムービー カキダシ';
  static const exportGif = 'ジフ カキダシ';
  static const exportSettingsTooltip = '書き出し設定';
  static const frameImageExporting = 'フレーム画像を書き出し中...';
  static const outputToPhotoLibrary = '出力先: フォトライブラリ';
  static String outputToPath(String path) => '出力先: $path';
  static const frameOutputToPhotoLibrary = '画像出力先: フォトライブラリ';
  static String frameOutputToPath(String path) => '画像出力先: $path';

  static const failedToGetVideoDuration = 'ムービーの長さを取得でなかった...';
  static const failedToParseVideoDuration = 'ムービー長さの解析に失敗した。ffprobeの設定を確認しよう。';
  static const invalidTrimRange = '開始点と終了点の範囲が不正だ！';
  static const invalidLoopCount = 'ループ回数は1以上で指定しよう。';
  static const trimming = 'トリミング中...';
  static const generatingGifPalette = 'GIFパレット生成中...';
  static const gifEncoding = 'GIFエンコード中...';
  static const exportDone = '書き出し完了';
  static const concatenating = '連結中...';
  static const generatingReverseClip = '逆再生クリップ生成中...';
  static const pingPongConcatenating = 'ピンポン連結中...';
  static const gifSingleCycleGenerating = 'GIF 1サイクル生成中...';
  static const ffmpegNotFoundInPath =
      'FFmpegが見つからない。PATHにffmpeg/ffprobeを追加しよう。';
  static String inputVideoNotFound(String path) => '入力動画が見つからない！: $path';
  static String failedToCopyInputVideo(String message) =>
      '入力動画の一時コピーに失敗した: $message';
  static const ffmpegExecutionFailed = 'FFmpegの実行に失敗した。';
  static const emptyInputVideoPath = '入力動画パスが空だ。';
  static String unsupportedInputPathFormat(String path) =>
      '未対応の入力パス形式です: $path';
  static String failedToParseInputPath(String path) => '入力動画パスの解析に失敗した: $path';
  static const failedToGetDetailedLog = '詳細ログを取得できなかった。';
  static const failedToStartFfmpeg = 'ffmpeg/ffprobe の起動に失敗した。';
  static const ffmpegNotInstalled =
      'ffmpeg/ffprobe が見つかりません。インストール後に再実行してください。';

  static const timelineZoom = 'ズーム';
  static const thumbnailLoading = 'サムネイル読み込み中...';
  static String savedToPhotoLibrary(String formatLabel) =>
      '$formatLabel をフォトライブラリに保存した！';
}
