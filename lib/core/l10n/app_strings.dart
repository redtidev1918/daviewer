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
  String get following => _lang == AppLanguage.zh ? '关注' : 'Following';
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
  String get switchAccount =>
      _lang == AppLanguage.zh ? '切换账号' : 'Switch account';
  String get switchingAccount =>
      _lang == AppLanguage.zh ? '正在切换账号…' : 'Switching account…';
  String get login => _lang == AppLanguage.zh ? '登录' : 'Login';
  String get webLogin => _lang == AppLanguage.zh ? '登录网页版' : 'Web login';
  String get notLoggedIn => _lang == AppLanguage.zh ? '未登录' : 'Not signed in';
  String get loginFirst => _lang == AppLanguage.zh ? '请先登录。' : 'Please sign in.';
  String get webSessionExpired =>
      _lang == AppLanguage.zh
          ? '网页会话已过期，请重新登录网页版以刷新首页推荐。'
          : 'Your web session expired. Sign in again to refresh home recommendations.';
  String get webLoggedInOAuthMissing =>
      _lang == AppLanguage.zh
          ? '网页版已登录，补全 App 登录后可使用收藏 / 关注 / 下载。'
          : 'Web session is signed in. Complete app login for favourites, watching and downloads.';
  String get webLoggedOutOAuthActive =>
      _lang == AppLanguage.zh
          ? 'App 已登录，但网页版尚未登录，首页推荐可能不是个性化内容。'
          : 'App is signed in, but the web home is not. Home recommendations may not be personalized.';
  String get noArtworks => _lang == AppLanguage.zh ? '暂无作品' : 'No artworks found.';
  String get noDaily => _lang == AppLanguage.zh ? '暂无每日推荐' : 'No daily deviations.';
  String get noWatched => _lang == AppLanguage.zh ? '暂无关注动态' : 'No watched artwork.';
  String get noFavourites => _lang == AppLanguage.zh ? '暂无收藏' : 'No favourites.';
  String get noDownloads => _lang == AppLanguage.zh ? '暂无下载' : 'No downloads.';
  String get noResults => _lang == AppLanguage.zh ? '无搜索结果' : 'No results found.';
  String get retry => _lang == AppLanguage.zh ? '重试' : 'Retry';
  String get refresh => _lang == AppLanguage.zh ? '刷新' : 'Refresh';
  String get back => _lang == AppLanguage.zh ? '返回' : 'Back';
  String get done => _lang == AppLanguage.zh ? '完成' : 'Done';
  String get pause => _lang == AppLanguage.zh ? '暂停' : 'Pause';
  String get resume => _lang == AppLanguage.zh ? '继续' : 'Resume';
  String get cancel => _lang == AppLanguage.zh ? '取消' : 'Cancel';
  String get language => _lang == AppLanguage.zh ? '语言' : 'Language';
  String get chinese => _lang == AppLanguage.zh ? '中文' : '中文 (Chinese)';
  String get english => _lang == AppLanguage.zh ? '英文' : 'English';
  String get proxy => _lang == AppLanguage.zh ? '网络代理' : 'Proxy';
  String get diagnostics =>
      _lang == AppLanguage.zh ? '日志与诊断' : 'Diagnostics';
  String get downloadOriginal =>
      _lang == AppLanguage.zh ? '下载原图' : 'Download original';
  String get original =>
      _lang == AppLanguage.zh ? '原图' : 'Original';
  String get description =>
      _lang == AppLanguage.zh ? '作品描述' : 'Description';
  String get artworkText =>
      _lang == AppLanguage.zh ? '作品文字' : 'Artwork text';
  String get about => _lang == AppLanguage.zh ? '关于' : 'About';
  String get githubRepository =>
      _lang == AppLanguage.zh ? 'GitHub 仓库' : 'GitHub repository';
  String get openInBrowser =>
      _lang == AppLanguage.zh ? '在浏览器中打开' : 'Open in browser';
  String get close => _lang == AppLanguage.zh ? '关闭' : 'Close';
  String get open => _lang == AppLanguage.zh ? '打开' : 'Open';

  // --- artwork detail ---
  String get artworkDetail =>
      _lang == AppLanguage.zh ? '作品详情' : 'Artwork detail';
  String get linkCopied => _lang == AppLanguage.zh ? '链接已复制' : 'Link copied';
  String get share => _lang == AppLanguage.zh ? '分享' : 'Share';
  String get favourite => _lang == AppLanguage.zh ? '收藏' : 'Favourite';
  String get unfavourite => _lang == AppLanguage.zh ? '取消收藏' : 'Unfavourite';
  String get bodyText => _lang == AppLanguage.zh ? '正文' : 'Text';
  String get originalStatusPrefix =>
      _lang == AppLanguage.zh ? '原图：' : 'Original: ';
  String get sizeLabel => _lang == AppLanguage.zh ? '大小：' : 'Size: ';
  String get fallbackDownloadNotice =>
      _lang == AppLanguage.zh
          ? '原图下载受限，将下载全尺寸预览图。'
          : 'Original download is restricted; downloading the full-size preview instead.';
  String get downloading => _lang == AppLanguage.zh ? '正在下载…' : 'Downloading…';
  String get downloadImage => _lang == AppLanguage.zh ? '下载图片' : 'Download image';
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

  String get hintLoginRequired =>
      _lang == AppLanguage.zh
          ? '该作品需要登录后才能下载原图。'
          : 'Sign in to download the original.';
  String get hintPurchaseRequired =>
      _lang == AppLanguage.zh
          ? '该作品需要付费订阅才能下载原图。'
          : 'A paid subscription is required to download the original.';
  String get hintRestricted =>
      _lang == AppLanguage.zh
          ? '该作品的原图下载受限。'
          : 'Downloading the original is restricted.';
  String get hintUnavailable =>
      _lang == AppLanguage.zh
          ? '该作品不提供原图下载。'
          : 'The original is not available for download.';

  // --- home open-link dialog ---
  String get openLinkTooltip => _lang == AppLanguage.zh ? '打开链接' : 'Open link';
  String get openLinkTitle =>
      _lang == AppLanguage.zh ? '打开 DeviantArt 链接' : 'Open DeviantArt link';
  String get openLinkHint =>
      _lang == AppLanguage.zh
          ? '粘贴作品或作者链接，例如\nhttps://www.deviantart.com/xxx/art/xxx-123456789'
          : 'Paste an artwork or author link, e.g.\nhttps://www.deviantart.com/xxx/art/xxx-123456789';

  // --- settings ---
  String get signedInWithDA =>
      _lang == AppLanguage.zh ? '已通过 DeviantArt 登录' : 'Signed in with DeviantArt';
  String get loginHint =>
      _lang == AppLanguage.zh
          ? '登录后可使用关注与收藏功能'
          : 'Login to use following and favourites';
  String get directProxy =>
      _lang == AppLanguage.zh ? '未使用代理（直连）' : 'Direct';
  String get viewLogs =>
      _lang == AppLanguage.zh ? '查看运行日志与错误记录' : 'View logs';
  String get aboutDAViewer =>
      _lang == AppLanguage.zh ? '关于 DAViewer' : 'About DAViewer';
  String get aboutDescription =>
      _lang == AppLanguage.zh
          ? '一个基于 DAKit 的第三方 DeviantArt 客户端。'
          : 'A third-party DeviantArt client built on DAKit.';

  // --- proxy settings ---
  String get proxyCurrentDirect =>
      _lang == AppLanguage.zh ? '当前生效：直连 DIRECT' : 'Current: Direct';
  String proxyCurrentConfigured(String hostPort) => _lang == AppLanguage.zh
      ? '当前生效：PROXY $hostPort'
      : 'Current: PROXY $hostPort';
  String get proxyHint =>
      _lang == AppLanguage.zh
          ? '国内访问 DeviantArt 需要代理。应用会自动读取系统代理；也可以在这里手动指定，例如 127.0.0.1:7890。'
          : 'A proxy is required to reach DeviantArt from some regions. The app auto-detects the system proxy; you can also set one here, e.g. 127.0.0.1:7890.';
  String get proxyAddressLabel =>
      _lang == AppLanguage.zh ? '代理地址 host:port' : 'Proxy address host:port';
  String get apply => _lang == AppLanguage.zh ? '应用' : 'Apply';
  String get restoreAutoDetect =>
      _lang == AppLanguage.zh ? '恢复自动检测' : 'Restore auto-detect';
  String get restoredAutoDetect =>
      _lang == AppLanguage.zh ? '已恢复自动检测' : 'Restored auto-detect';
  String get invalidProxyFormat =>
      _lang == AppLanguage.zh
          ? '格式应为 host:port，例如 127.0.0.1:7890'
          : 'Format must be host:port, e.g. 127.0.0.1:7890';
  String invalidProxyPort(String port) =>
      _lang == AppLanguage.zh ? '端口无效：$port' : 'Invalid port: $port';
  String appliedProxy(String hostPort) =>
      _lang == AppLanguage.zh ? '已应用代理 $hostPort' : 'Applied proxy $hostPort';

  // --- diagnostics ---
  String get noLogYet => _lang == AppLanguage.zh ? '（暂无日志）' : '(No logs yet)';
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
  String get permissionDeniedWatch =>
      _lang == AppLanguage.zh
          ? '权限不足，请退出登录后重新登录以获取关注权限。'
          : 'Permission denied. Please sign out and sign in again to get watch permission.';
}
