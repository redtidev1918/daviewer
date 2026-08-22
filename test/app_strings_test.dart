import 'package:daviewer/core/l10n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const en = AppStrings.en;
  const zh = AppStrings.zh;

  test('notificationTypeLabel maps known types (English)', () {
    expect(en.notificationTypeLabel('watched'), 'watched you');
    expect(en.notificationTypeLabel('deviation'), 'posted new work');
    expect(en.notificationTypeLabel('favourited'), 'favourited your work');
    expect(en.notificationTypeLabel('comment'), 'commented on your work');
    expect(en.notificationTypeLabel('mention'), 'mentioned you');
    expect(
      en.notificationTypeLabel('collection'),
      'added your work to a collection',
    );
    expect(en.notificationTypeLabel('journal'), 'posted a journal');
    expect(en.notificationTypeLabel('gift'), 'sent you a gift');
    expect(en.notificationTypeLabel('note'), 'sent you a note');
    expect(en.notificationTypeLabel('llama'), 'gave you a Llama');
    expect(en.notificationTypeLabel('status'), 'updated their status');
  });

  test('notificationTypeLabel has a default and Chinese works', () {
    expect(en.notificationTypeLabel('unknown'), 'posted an update');
    expect(zh.notificationTypeLabel('watched'), '关注了你');
  });

  test('folderArtworkCount formats count', () {
    expect(en.folderArtworkCount(3), '3 artworks');
    expect(zh.folderArtworkCount(3), '3 作品');
  });

  test('artistStats formats stats', () {
    expect(en.artistStats(10, 5), '10 deviations · 5 favourites');
    expect(zh.artistStats(10, 5), '10 作品 · 5 收藏');
  });

  test('relativeTime uses the right bucket', () {
    final now = DateTime.now();
    expect(en.relativeTime(null), isEmpty);
    expect(en.relativeTime(now.subtract(const Duration(seconds: 5))), 'now');
    expect(en.relativeTime(now.subtract(const Duration(minutes: 5))), '5m ago');
    expect(en.relativeTime(now.subtract(const Duration(hours: 2))), '2h ago');
    expect(en.relativeTime(now.subtract(const Duration(days: 3))), '3d ago');
  });

  test('login help strings are localized', () {
    expect(zh.loginHelpTooltip, '登录帮助');
    expect(en.loginHelpTooltip, 'Login help');
    expect(zh.forgotPassword, '找回密码');
    expect(en.forgotPassword, 'Forgot password');
    expect(zh.registerAccount, '注册 DeviantArt 账号');
    expect(en.registerAccount, 'Register a DeviantArt account');
    expect(zh.loginHelpBody, contains('任意邮箱'));
    expect(en.loginHelpBody, contains('DeviantArt account'));
  });
}
