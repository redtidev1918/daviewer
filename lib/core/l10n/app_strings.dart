import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported UI languages.
enum AppLanguage { zh, en }

/// A minimal localization controller. UI strings live in [AppStrings], which
/// selects a language based on [AppLanguageController.current].
final class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController() : super(AppLanguage.zh);

  void set(AppLanguage language) => state = language;
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>(
      (ref) => AppLanguageController(),
    );

/// Returns the active localized string table.
AppStrings strings(AppLanguage language) => AppStrings.of(language);

/// Localized strings for the app. Add new keys here as the UI grows.
final class AppStrings {
  const AppStrings._(this._lang);

  factory AppStrings.of(AppLanguage language) =>
      language == AppLanguage.zh ? zh : en;

  final AppLanguage _lang;

  static const AppStrings zh = AppStrings._(AppLanguage.zh);
  static const AppStrings en = AppStrings._(AppLanguage.en);

  String get appTitle => _lang == AppLanguage.zh ? 'DA 查看器' : 'DA Viewer';
  String get home => _lang == AppLanguage.zh ? '推荐' : 'For you';
  String get daily => _lang == AppLanguage.zh ? '每日推荐' : 'Daily';
  String get following => _lang == AppLanguage.zh ? '关注动态' : 'Watched';
  String get search => _lang == AppLanguage.zh ? '搜索' : 'Search';
  String get gallery => _lang == AppLanguage.zh ? '画廊' : 'Gallery';
  String get favourites => _lang == AppLanguage.zh ? '收藏' : 'Favourites';
  String get downloads => _lang == AppLanguage.zh ? '下载' : 'Downloads';
  String get notifications => _lang == AppLanguage.zh ? '通知' : 'Notifications';
  String get noNotifications =>
      _lang == AppLanguage.zh ? '暂无通知' : 'No notifications.';
  String get settings => _lang == AppLanguage.zh ? '设置' : 'Settings';
  String get logout => _lang == AppLanguage.zh ? '退出登录' : 'Logout';
  String get signedOut => _lang == AppLanguage.zh ? '已登出' : 'Signed out';
  String get login => _lang == AppLanguage.zh ? '登录' : 'Login';
  String get webLogin => _lang == AppLanguage.zh ? '登录网页版' : 'Web login';
  String get notLoggedIn => _lang == AppLanguage.zh ? '未登录' : 'Not signed in';
  String get loginFirst =>
      _lang == AppLanguage.zh ? '请先登录。' : 'Please sign in.';
  String get webSessionExpired => _lang == AppLanguage.zh
      ? '网页会话已过期，请重新登录网页版以刷新首页推荐。'
      : 'Your web session expired. Sign in again to refresh home recommendations.';
  String get webLoggedInOAuthMissing => _lang == AppLanguage.zh
      ? '网页版已登录，补全 App 登录后可使用收藏 / 关注 / 下载。'
      : 'Web session is signed in. Complete app login for favourites, watching and downloads.';
  String get webLoggedOutOAuthActive => _lang == AppLanguage.zh
      ? 'App 已登录，但网页版尚未登录，首页推荐可能不是个性化内容。'
      : 'App is signed in, but the web home is not. Home recommendations may not be personalized.';

  // --- login help ---
  String get loginHelpTooltip =>
      _lang == AppLanguage.zh ? '登录帮助' : 'Login help';
  String get loginHelpTitle =>
      _lang == AppLanguage.zh ? '登录帮助' : 'Sign-in help';
  String get loginHelpBody => _lang == AppLanguage.zh
      ? '本页登录的是 DeviantArt 官方账号。DAViewer 不注册账号、不保存密码。\n\n'
            '• 注册：支持任意邮箱注册，登录页也提供一键登录。\n'
            '• 找回密码：点击登录页的「Forgot Password」，或使用下方「找回密码」在浏览器中重置。\n'
            '• 找回密码与注册均在系统浏览器中完成，完成后返回本页登录。'
      : 'This page signs in to your DeviantArt account. DAViewer does not create accounts or store passwords.\n\n'
            '• Register: any email works; the page also offers one-click sign-in.\n'
            '• Forgot password: tap "Forgot Password" on the page, or use "Forgot password" below to reset it in your browser.\n'
            '• Password reset and registration open in your browser; return here to sign in afterwards.';
  String get forgotPassword =>
      _lang == AppLanguage.zh ? '找回密码' : 'Forgot password';
  String get registerAccount => _lang == AppLanguage.zh
      ? '注册 DeviantArt 账号'
      : 'Register a DeviantArt account';
  String get webLoginSuccess =>
      _lang == AppLanguage.zh ? '网页登录成功' : 'Web sign-in succeeded';
  String get loginSuccess => _lang == AppLanguage.zh ? '登录成功' : 'Signed in';
  String loginFailed(String detail) =>
      _lang == AppLanguage.zh ? '登录失败：$detail' : 'Sign-in failed: $detail';
  String get noArtworks =>
      _lang == AppLanguage.zh ? '暂无作品' : 'No artworks found.';
  String get noImage => _lang == AppLanguage.zh ? '暂无图片' : 'No image';
  String get imageLoadFailed =>
      _lang == AppLanguage.zh ? '图片加载失败' : 'Failed to load';
  String get previousArtwork =>
      _lang == AppLanguage.zh ? '上一个作品' : 'Previous artwork';
  String get nextArtwork => _lang == AppLanguage.zh ? '下一个作品' : 'Next artwork';
  String get videoLoadFailed =>
      _lang == AppLanguage.zh ? '视频加载失败' : 'Video failed to load';
  String get byPrefix => _lang == AppLanguage.zh ? '作者：' : 'by ';
  String get recommendedTags =>
      _lang == AppLanguage.zh ? '为你推荐' : 'Recommended for you';
  String get noDaily =>
      _lang == AppLanguage.zh ? '暂无每日推荐' : 'No daily deviations.';
  String get noWatched => _lang == AppLanguage.zh
      ? '你还没有关注任何用户。关注喜欢的创作者后，他们的新作品会出现在这里。'
      : 'You are not watching anyone yet. Follow creators to see their new artwork here.';
  String get watchedFeedLoadFailure => _lang == AppLanguage.zh
      ? '关注动态暂时无法加载，请稍后重试。'
      : 'Your watched feed is temporarily unavailable. Try again later.';
  String get noFavourites =>
      _lang == AppLanguage.zh ? '暂无收藏' : 'No favourites.';
  String get noDownloads => _lang == AppLanguage.zh ? '暂无下载' : 'No downloads.';
  String get deleteFinishedDownloads =>
      _lang == AppLanguage.zh ? '删除已结束下载' : 'Delete finished downloads';
  String get deleteFinishedDownloadsTitle =>
      _lang == AppLanguage.zh ? '删除已结束的下载？' : 'Delete finished downloads?';
  String deleteFinishedDownloadsMessage(int count) {
    if (_lang == AppLanguage.zh) {
      return '将删除 $count 条已结束的下载记录及其本地文件（如有）。此操作无法撤销。';
    }
    final record = count == 1 ? 'record' : 'records';
    return 'This will permanently delete $count finished download $record and any local files. This cannot be undone.';
  }

  String get deleteAction => _lang == AppLanguage.zh ? '删除' : 'Delete';
  String deleteFinishedDownloadsFailed(String detail) =>
      _lang == AppLanguage.zh ? '删除失败：$detail' : 'Delete failed: $detail';
  String get noResults =>
      _lang == AppLanguage.zh ? '无搜索结果' : 'No results found.';
  String get retry => _lang == AppLanguage.zh ? '重试' : 'Retry';
  String get refresh => _lang == AppLanguage.zh ? '刷新' : 'Refresh';
  String get done => _lang == AppLanguage.zh ? '完成' : 'Done';
  String get pause => _lang == AppLanguage.zh ? '暂停' : 'Pause';
  String get resume => _lang == AppLanguage.zh ? '继续' : 'Resume';
  String get cancel => _lang == AppLanguage.zh ? '取消' : 'Cancel';
  String get language => _lang == AppLanguage.zh ? '语言' : 'Language';
  String get chinese => _lang == AppLanguage.zh ? '中文' : '中文 (Chinese)';
  String get english => _lang == AppLanguage.zh ? '英文' : 'English';
  String get proxy => _lang == AppLanguage.zh ? '网络代理' : 'Proxy';
  String get diagnostics => _lang == AppLanguage.zh ? '日志与诊断' : 'Diagnostics';
  String get downloadOriginal =>
      _lang == AppLanguage.zh ? '下载原图' : 'Download original';
  String get original => _lang == AppLanguage.zh ? '原图' : 'Original';
  String get description => _lang == AppLanguage.zh ? '作品描述' : 'Description';
  String get about => _lang == AppLanguage.zh ? '关于' : 'About';
  String get githubRepository =>
      _lang == AppLanguage.zh ? 'GitHub 仓库' : 'GitHub repository';
  String get releases => _lang == AppLanguage.zh ? '版本发布' : 'Releases';
  String get close => _lang == AppLanguage.zh ? '关闭' : 'Close';
  String get open => _lang == AppLanguage.zh ? '打开' : 'Open';
  String get openFolder => _lang == AppLanguage.zh ? '打开文件夹' : 'Open folder';

  // --- artwork detail ---
  String get artworkDetail =>
      _lang == AppLanguage.zh ? '作品详情' : 'Artwork detail';
  String get linkCopied => _lang == AppLanguage.zh ? '链接已复制' : 'Link copied';
  String get copyLink => _lang == AppLanguage.zh ? '复制链接' : 'Copy link';
  String get openInBrowser =>
      _lang == AppLanguage.zh ? '在浏览器打开' : 'Open in browser';
  String get share => _lang == AppLanguage.zh ? '分享' : 'Share';
  String get favourite => _lang == AppLanguage.zh ? '收藏' : 'Favourite';
  String get unfavourite => _lang == AppLanguage.zh ? '取消收藏' : 'Unfavourite';
  String get favouritedToast => _lang == AppLanguage.zh ? '已收藏' : 'Favourited';
  String get unfavouritedToast =>
      _lang == AppLanguage.zh ? '已取消收藏' : 'Removed from favourites';
  String get bodyText => _lang == AppLanguage.zh ? '正文' : 'Text';
  String get originalStatusPrefix =>
      _lang == AppLanguage.zh ? '原图：' : 'Original: ';
  String get sizeLabel => _lang == AppLanguage.zh ? '大小：' : 'Size: ';
  String get fallbackDownloadNotice => _lang == AppLanguage.zh
      ? '原图不可下载，但可以保存当前展示的最高画质图片。'
      : 'The original is unavailable, but the highest-quality displayed image can be saved.';
  String get downloadUnavailableReason =>
      _lang == AppLanguage.zh ? '不能下载的原因' : 'Why downloading is unavailable';
  String get checkingDownloadAvailability => _lang == AppLanguage.zh
      ? '正在确认当前账号的下载权限…'
      : 'Checking download access for this account…';
  String get downloadAvailabilityCheckFailed => _lang == AppLanguage.zh
      ? '暂时无法确认下载权限，可能是网络、登录会话或服务异常。请重试。'
      : 'Download permission could not be verified. Check the network/session and retry.';
  String get retryDownloadCheck =>
      _lang == AppLanguage.zh ? '重新检查下载权限' : 'Check again';
  String get downloadLimitReached => _lang == AppLanguage.zh
      ? '当前账号的免费下载次数已用完。'
      : 'This account has reached its free-download limit.';
  String get creatorDisabledDownload => _lang == AppLanguage.zh
      ? '作者没有开放这件作品的原图下载。'
      : 'The creator has not enabled original downloads for this artwork.';
  String providerDownloadReason(String reason) => _lang == AppLanguage.zh
      ? 'DeviantArt 返回的原因：$reason'
      : 'DeviantArt says: $reason';
  String downloadFailed(String reason) =>
      _lang == AppLanguage.zh ? '下载失败：$reason' : 'Download failed: $reason';
  String get downloadFailureNetwork => _lang == AppLanguage.zh
      ? '网络连接中断或请求超时，请检查网络后重试。'
      : 'The connection failed or timed out. Check your network and retry.';
  String get downloadFailurePermission => _lang == AppLanguage.zh
      ? '当前账号或登录会话没有下载权限，请重新登录或检查作品限制。'
      : 'This account or session is not allowed to download the file.';
  String get downloadFailureNotFound => _lang == AppLanguage.zh
      ? '下载源已失效、被删除或不再提供。'
      : 'The source file expired, was removed, or is no longer offered.';
  String get downloadFailureStorage => _lang == AppLanguage.zh
      ? '无法写入本地文件，请检查存储空间和文件夹权限。'
      : 'The file could not be written. Check free space and folder permissions.';
  String get downloading => _lang == AppLanguage.zh ? '正在下载…' : 'Downloading…';
  String get downloadImage =>
      _lang == AppLanguage.zh ? '下载图片' : 'Download image';
  String get savedToPrefix => _lang == AppLanguage.zh ? '已保存到 ' : 'Saved to ';
  String get zoomIn => _lang == AppLanguage.zh ? '放大' : 'Zoom in';
  String get zoomReset => _lang == AppLanguage.zh ? '重置缩放' : 'Reset zoom';

  String get availabilityAvailable =>
      _lang == AppLanguage.zh ? '可下载' : 'Available';
  String get availabilityLoginRequired =>
      _lang == AppLanguage.zh ? '需要登录' : 'Login required';
  String get availabilityPurchaseRequired =>
      _lang == AppLanguage.zh ? '需要购买' : 'Purchase required';
  String get availabilityRestricted =>
      _lang == AppLanguage.zh ? '受限' : 'Restricted';
  String get availabilityUnavailable =>
      _lang == AppLanguage.zh ? '不可下载' : 'Unavailable';
  String get availabilityMissing =>
      _lang == AppLanguage.zh ? '已删除或不存在' : 'Deleted or unavailable';

  String get hintLoginRequired => _lang == AppLanguage.zh
      ? '该作品需要登录后才能下载原图。'
      : 'Sign in to download the original.';
  String get hintPurchaseRequired => _lang == AppLanguage.zh
      ? '该作品需要付费订阅才能下载原图。'
      : 'A paid subscription is required to download the original.';
  String get hintRestricted => _lang == AppLanguage.zh
      ? '该作品的原图下载受限。'
      : 'Downloading the original is restricted.';
  String get hintUnavailable => _lang == AppLanguage.zh
      ? '该作品不提供原图下载。'
      : 'The original is not available for download.';
  String get hintMissing => _lang == AppLanguage.zh
      ? '作品或原始文件已删除、不存在，或下载链接已经失效。'
      : 'The artwork or original file was removed, is missing, or its link expired.';

  // --- home open-link dialog ---
  String get openLinkTooltip => _lang == AppLanguage.zh ? '打开链接' : 'Open link';
  String get openLinkTitle =>
      _lang == AppLanguage.zh ? '打开 DeviantArt 链接' : 'Open DeviantArt link';
  String get openLinkHint => _lang == AppLanguage.zh
      ? '粘贴作品或作者链接，例如\nhttps://www.deviantart.com/xxx/art/xxx-123456789'
      : 'Paste an artwork or author link, e.g.\nhttps://www.deviantart.com/xxx/art/xxx-123456789';

  // --- settings ---
  String get signedInWithDA => _lang == AppLanguage.zh
      ? '已通过 DeviantArt 登录'
      : 'Signed in with DeviantArt';
  String get loginHint => _lang == AppLanguage.zh
      ? '登录后可使用关注与收藏功能'
      : 'Login to use following and favourites';
  String get directProxy => _lang == AppLanguage.zh ? '未使用代理（直连）' : 'Direct';
  String get viewLogs => _lang == AppLanguage.zh ? '查看运行日志与错误记录' : 'View logs';
  String get aboutDAViewer =>
      _lang == AppLanguage.zh ? '关于 DAViewer' : 'About DAViewer';
  String get aboutDescription => _lang == AppLanguage.zh
      ? '一个基于 DAKit 的第三方 DeviantArt 客户端。'
      : 'A third-party DeviantArt client built on DAKit.';

  // --- proxy settings ---
  String get proxyCurrentDirect =>
      _lang == AppLanguage.zh ? '当前生效：直连 DIRECT' : 'Current: Direct';
  String proxyCurrentConfigured(String hostPort) => _lang == AppLanguage.zh
      ? '当前生效：PROXY $hostPort'
      : 'Current: PROXY $hostPort';
  String get proxyHint => _lang == AppLanguage.zh
      ? '国内访问 DeviantArt 需要代理。应用会自动读取系统代理；也可以在这里手动指定，例如 127.0.0.1:7890。'
      : 'A proxy is required to reach DeviantArt from some regions. The app auto-detects the system proxy; you can also set one here, e.g. 127.0.0.1:7890.';
  String get proxyAddressLabel =>
      _lang == AppLanguage.zh ? '代理地址 host:port' : 'Proxy address host:port';
  String get apply => _lang == AppLanguage.zh ? '应用' : 'Apply';
  String get restoreAutoDetect =>
      _lang == AppLanguage.zh ? '恢复自动检测' : 'Restore auto-detect';
  String get restoredAutoDetect =>
      _lang == AppLanguage.zh ? '已恢复自动检测' : 'Restored auto-detect';
  String get invalidProxyFormat => _lang == AppLanguage.zh
      ? '格式应为 host:port，例如 127.0.0.1:7890'
      : 'Format must be host:port, e.g. 127.0.0.1:7890';
  String invalidProxyPort(String port) =>
      _lang == AppLanguage.zh ? '端口无效：$port' : 'Invalid port: $port';
  String appliedProxy(String hostPort) =>
      _lang == AppLanguage.zh ? '已应用代理 $hostPort' : 'Applied proxy $hostPort';

  // --- diagnostics ---
  String get noLogFile =>
      _lang == AppLanguage.zh ? '（暂无日志文件）' : '(No log file yet)';
  String logReadFailed(Object error) =>
      _lang == AppLanguage.zh ? '读取日志失败：$error' : 'Failed to read log: $error';
  String get noErrorsThisRun =>
      _lang == AppLanguage.zh ? '本次运行无错误' : 'No errors this run';
  String errorsThisRun(int count) => _lang == AppLanguage.zh
      ? '本次运行记录到 $count 个错误'
      : 'Logged $count errors this run.';
  String logDirectory(String dir) =>
      _lang == AppLanguage.zh ? '日志目录：\n$dir' : 'Log directory:\n$dir';

  // --- folders ---
  String get emptyFolder => _lang == AppLanguage.zh ? '空画集' : 'Empty folder';
  String get folder => _lang == AppLanguage.zh ? '画集' : 'Folder';
  String get permissionDeniedWatch => _lang == AppLanguage.zh
      ? '权限不足，请退出登录后重新登录以获取关注权限。'
      : 'Permission denied. Please sign out and sign in again to get watch permission.';

  // --- notifications ---
  String get unknownUser => _lang == AppLanguage.zh ? '未知用户' : 'Unknown user';
  String get notifPermissionError => _lang == AppLanguage.zh
      ? '登录授权已过期或缺少「通知」权限，请退出登录后重新登录一次。'
      : 'Your login is missing the notifications permission. Please log out and log back in once.';

  String notificationTypeLabel(String type) {
    final zh = _lang == AppLanguage.zh;
    return switch (type) {
      'watched' || 'watch' => zh ? '关注了你' : 'watched you',
      'deviation' ||
      'new_deviation' ||
      'posted' => zh ? '更新了作品' : 'posted new work',
      'deviation_faved' ||
      'faved' ||
      'favourited' => zh ? '收藏了你的作品' : 'favourited your work',
      'deviation_comment' ||
      'comment_deviation' ||
      'comment' => zh ? '评论了你的作品' : 'commented on your work',
      'mention' || 'mention_deviation' => zh ? '提到了你' : 'mentioned you',
      'collection' || 'added_to_collection' =>
        zh ? '把你的作品加入收藏集' : 'added your work to a collection',
      'journal' || 'journal_faved' => zh ? '发布了日志' : 'posted a journal',
      'gift' => zh ? '送了你礼物' : 'sent you a gift',
      'note' => zh ? '给你发了私信' : 'sent you a note',
      'llama' => zh ? '送你一个 Llama' : 'gave you a Llama',
      'status' || 'status_update' => zh ? '更新了状态' : 'updated their status',
      _ => zh ? '更新了动态' : 'posted an update',
    };
  }

  String relativeTime(DateTime? time) {
    if (time == null) return '';
    final zh = _lang == AppLanguage.zh;
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inMinutes < 1) return zh ? '刚刚' : 'now';
    if (diff.inHours < 1) {
      return zh ? '${diff.inMinutes} 分钟前' : '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return zh ? '${diff.inHours} 小时前' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 30) {
      return zh ? '${diff.inDays} 天前' : '${diff.inDays}d ago';
    }
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  // --- transfers / downloads ---
  String get viewDetail => _lang == AppLanguage.zh ? '查看详情' : 'View details';
  String get transferDone => _lang == AppLanguage.zh ? '已完成' : 'Done';
  String get transferDownloading =>
      _lang == AppLanguage.zh ? '下载中' : 'Downloading';
  String get transferPaused => _lang == AppLanguage.zh ? '已暂停' : 'Paused';
  String get transferFailed => _lang == AppLanguage.zh ? '失败' : 'Failed';
  String get transferNotFound =>
      _lang == AppLanguage.zh ? '源文件失效' : 'Source unavailable';
  String get transferCancelled => _lang == AppLanguage.zh ? '已取消' : 'Cancelled';
  String get transferQueued => _lang == AppLanguage.zh ? '排队中' : 'Queued';

  // --- watching ---
  String get watching => _lang == AppLanguage.zh ? '关注用户' : 'Watching';
  String get noWatchedUsers =>
      _lang == AppLanguage.zh ? '尚未关注任何用户' : 'No watched users';
  String get watchListPermissionError => _lang == AppLanguage.zh
      ? '获取关注列表失败：权限不足。\n请退出登录后重新登录，以获取最新权限。'
      : 'Permission denied. Please sign out and sign in again.';

  // --- artist ---
  String get watchStateOn => _lang == AppLanguage.zh ? '已关注' : 'Following';
  String get watchStateOff => _lang == AppLanguage.zh ? '关注' : 'Watch';
  String get journal => _lang == AppLanguage.zh ? '文章' : 'Journal';
  String get folders => _lang == AppLanguage.zh ? '画集' : 'Folders';
  String get noJournals => _lang == AppLanguage.zh ? '暂无文章' : 'No journals';
  String get noFolders => _lang == AppLanguage.zh ? '暂无画集' : 'No folders';
  String get emptyFolderBadge => _lang == AppLanguage.zh ? '空画集' : 'Empty';
  String folderArtworkCount(int count) =>
      _lang == AppLanguage.zh ? '$count 作品' : '$count artworks';
  String artistStats(int deviations, int favourites) => _lang == AppLanguage.zh
      ? '$deviations 作品 · $favourites 收藏'
      : '$deviations deviations · $favourites favourites';

  // --- search ---
  String get searchHint => _lang == AppLanguage.zh
      ? '搜索作品 / 用户，或用 #标签 搜标签'
      : 'Search artworks, users, or #tags';
  String get clear => _lang == AppLanguage.zh ? '清空' : 'Clear';
  String get clearHistory => _lang == AppLanguage.zh ? '清除' : 'Clear';
  String get artworks => _lang == AppLanguage.zh ? '作品' : 'Artworks';
  String get users => _lang == AppLanguage.zh ? '用户' : 'Users';
  String get popularTags => _lang == AppLanguage.zh ? '热门标签' : 'Popular tags';
  String get discover => _lang == AppLanguage.zh ? '去发现' : 'Discover';
  String get discoverArtists =>
      _lang == AppLanguage.zh ? '发现并关注' : 'Find creators';
  String get popularTagsHint =>
      _lang == AppLanguage.zh ? '点击标签浏览该标签下的作品' : 'Tap a tag to browse it';
  String get searchIdleHint => _lang == AppLanguage.zh
      ? '输入关键词搜索作品，或输入 #标签 浏览标签。'
      : 'Search artworks, or type #tag to browse a tag.';
  String get recent => _lang == AppLanguage.zh ? '搜索记录' : 'Recent';
  String get noUsersFound =>
      _lang == AppLanguage.zh ? '无搜索结果' : 'No users found';

  // --- tag ---
  String get relatedTags => _lang == AppLanguage.zh ? '相关标签' : 'Related tags';
  String get moreLikeThis =>
      _lang == AppLanguage.zh ? '更多类似作品' : 'More like this';
  String get moreLikeThisLoadFailed =>
      _lang == AppLanguage.zh ? '更多类似作品加载失败' : 'Could not load similar artwork';
  String get moreLikeThisLoading =>
      _lang == AppLanguage.zh ? '正在寻找更多类似作品…' : 'Finding more similar artwork…';
  String get noMoreLikeThis => _lang == AppLanguage.zh
      ? '暂时没有找到更多类似作品。你可以稍后再检查，推荐结果可能会更新。'
      : 'No more similar artwork was found yet. Check again later as recommendations may update.';
  String get checkSuggestions =>
      _lang == AppLanguage.zh ? '检查更新' : 'Check again';
  String get moreLikeThisChecking =>
      _lang == AppLanguage.zh ? '正在检查…' : 'Checking…';
  String get moreLikeThisStillEmpty => _lang == AppLanguage.zh
      ? '已检查最新推荐，目前没有新结果。'
      : 'The latest recommendations were checked; there are no new results.';
  String get moreLikeThisUnchanged => _lang == AppLanguage.zh
      ? '已重新检查，当前类似作品没有变化。'
      : 'Checked again; suggestions are unchanged.';
  String moreLikeThisUpdated(int count) => _lang == AppLanguage.zh
      ? '已更新，找到 $count 个类似作品。'
      : 'Updated with $count similar artwork${count == 1 ? '' : 's'}.';
  String get moreLikeThisRecovering => _lang == AppLanguage.zh
      ? '相关推荐暂时中断，正在自动恢复…'
      : 'Suggestions were interrupted. Recovering automatically…';
  String get moreLikeThisNetworkFailure => _lang == AppLanguage.zh
      ? '网络连接失败，自动重试后仍无法加载。请检查代理或网络。'
      : 'The network failed after an automatic retry. Check your connection or proxy.';
  String get moreLikeThisSessionFailure => _lang == AppLanguage.zh
      ? 'DeviantArt 登录会话已失效，重新登录后即可恢复。'
      : 'Your DeviantArt session expired. Sign in again to restore suggestions.';
  String get moreLikeThisServiceFailure => _lang == AppLanguage.zh
      ? 'DeviantArt 暂时不可用或限制了请求，作品详情本身不受影响。'
      : 'DeviantArt is temporarily unavailable or limiting requests. Artwork details still work.';
  String get moreLikeThisFormatFailure => _lang == AppLanguage.zh
      ? '相关推荐暂时加载不完整，稍后再试即可。作品详情不受影响。'
      : 'Similar artwork did not finish loading. Try again later; artwork details are unaffected.';
  String get moreLikeThisUnknownFailure => _lang == AppLanguage.zh
      ? '相关推荐暂时不可用，作品详情本身仍可正常浏览。'
      : 'Suggestions are temporarily unavailable. Artwork details still work.';
  String get reloadSuggestions => _lang == AppLanguage.zh ? '重新加载' : 'Reload';

  // --- OAuth configuration errors (developer-facing) ---
  String get oauthClientIdMissing => _lang == AppLanguage.zh
      ? 'OAuth 登录需要配置 DAKIT_CLIENT_ID。'
      : 'OAuth login requires DAKIT_CLIENT_ID.';
  String get oauthClientIdInvalid => _lang == AppLanguage.zh
      ? 'DAKIT_CLIENT_ID 无效或未在 DeviantArt 注册。\n'
            '请在 deviantart.com/settings/applications 注册一个 '
            'Public OAuth 应用，并把 client_id 通过 '
            '--dart-define=DAKIT_CLIENT_ID=你的ID 传入。'
      : 'DAKIT_CLIENT_ID is invalid or not registered with DeviantArt.\n'
            'Register a Public OAuth app at deviantart.com/settings/applications '
            'and pass the client_id via --dart-define=DAKIT_CLIENT_ID=YOUR_ID.';
}
