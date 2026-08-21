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
}
