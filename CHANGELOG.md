# Changelog

本文件只记录用户可见的变更。逐提交的历史见
[Releases](https://github.com/redtidev1918/daviewer/releases)。

## 0.2.4

### Added

- 首页改为内嵌 DeviantArt 网页版首页，个性化推荐与网页版一致
  （`rfy/deviations`）
- 复用首页 WebView 的网页登录态完成 OAuth 授权（网页已登录时无需重输密码）
- 首页原生 AppBar、加载进度条、下拉刷新、Android 返回键接管
- 顶部登录态同步提示条

### Fixed

- 修复 WebView OAuth 回调被顺序 `yield*` 吞掉、导致应用内登录超时的问题
- 修复 release APK 无法构建的问题（回退稳定版 `flutter_inappwebview`，
  并把 AGP 降到 8.13.2 / Gradle 8.14.2 / Kotlin 2.2.20）

### Changed

- 依赖 `dakit_core` / `dakit_api` 升级到 0.1.1

## 0.2.2

### Fixed

- 修复重启后登录态无法恢复、每次都要重新登录的问题
- 修复切换账号后首页仍显示上一个账号内容的问题

### Added

- 设置页「切换账号」入口（登出当前会话并重新授权）

## 0.2.1

- 首个发布版本：OAuth 登录、作品浏览 / 详情 / 大图缩放、后台下载、收藏、
  关注、搜索、双语、代理配置。
