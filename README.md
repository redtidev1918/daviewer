# DAViewer

一个基于 [DAKit](https://github.com/redtidev1918/dakit) 的第三方 DeviantArt 客户端。
A third-party DeviantArt client built on [DAKit](https://github.com/redtidev1918/dakit).

## 功能特性 / Features

- **登录**：OAuth 登录，内置公开 client id，普通用户开箱即用；复用首页
  WebView 的网页登录态，网页版已登录时无需重新输入密码
- **首页**：内嵌 DeviantArt 网页版首页，个性化推荐与网页版一致
  （`rfy/deviations`）；原生 AppBar、加载进度条、下拉刷新、Android 返回键接管
- **搜索**：关键词搜索 + 历史记录
- **作品详情**：图片 / 视频（可拖动进度条）/ GIF 播放，富文本简介（网页抓取）
- **大图查看**：全屏、双击缩放、捏合缩放
- **下载**：原图后台下载，受限时回退全尺寸预览；下载记录支持打开文件/文件夹
- **社交**：收藏作品、关注/取消关注作者、关注用户列表
- **作者**：资料、画廊、收藏夹
- **双语**：中文 / English 切换
- **代理**：自动检测系统代理 + 手动配置（国内访问必需）

## 与 DAKit 的关系 / Relationship with DAKit

`DAViewer` 是应用，DAKit 是 SDK。客户端只依赖 DAKit，不复制 SDK 代码。
DAKit 已发布到 pub.dev，客户端直接使用版本化依赖：

```yaml
dependencies:
  dakit_flutter: ^0.1.0
```

## 安装 / Install

从 [Releases](https://github.com/redtidev1918/daviewer/releases) 下载对应平台的安装包：

- **Android**：`DAViewer-<版本>.apk`
- **macOS**：`DAViewer-<版本>-macos.zip`（解压后拖入「应用程序」）

> 注意：macOS 未签名，首次打开需右键「打开」或到「系统设置 → 隐私与安全性」允许。

## 使用前准备

普通用户只需要一个 DeviantArt 账号，无需注册 OAuth 应用 —— 客户端内置了
公开的 client id（Public OAuth client 没有 secret，client id 可以随应用分发）。

> 登录需要以下 OAuth 权限（应用启动时自动申请）：`basic`、`browse`、
> `collection`（收藏）、`user`（关注列表）、`user.manage`（关注/取消关注）、
> `gallery`、`feed`。

### 开发者：覆盖内置 client id

如果想用自己的 OAuth 应用（例如开发调试），通过 `--dart-define` 覆盖：

```shell
flutter run -d macos --dart-define=DAKIT_CLIENT_ID=你的_PUBLIC_CLIENT_ID
```

> 用自己的应用时，需在其白名单中精确加入 `dakit://oauth/callback`。

## 运行 / Run

```shell
flutter pub get
flutter run -d macos     # macOS
flutter run -d android   # Android
flutter run -d windows   # Windows
```

## 代理 / Proxy

应用运行时会自动读取系统代理（macOS 通过 `scutil`，Windows 通过注册表）。若需手动指定，
可在「设置 → 网络代理」中填写 `host:port`。

`flutter pub get` 走 Dart HTTP 客户端，不走 Git 代理；如需代理访问 pub.dev：

```shell
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export no_proxy=localhost,127.0.0.1
flutter pub get
```

## 构建 Release / Release Build

推送到 `main` 会触发 CI 的质量检查与 Android/macOS 构建；打 `v*` 标签会自动创建
GitHub Release 并上传构建产物（带版本号、自动生成 changelog、只保留最新 release）。

Release APK 始终使用 upload keystore 签名（来自 CI 的 `KEYSTORE_B64` /
`KEYSTORE_PROPERTIES` secret）；本地无 `android/key.properties` 时 release 构建会
直接报错，避免误用 debug 签名导致「无法覆盖安装」的签名不一致问题。

### 一键发布（推荐）

Actions → **Release** → Run workflow → 选 `patch` / `minor` / `major`（或填具体
版本号）→ 运行。它会自动改版本号、提交、推 tag，随后 CI 构建并发布。

### 手动发布

```shell
# 1. 改 pubspec.yaml 的 version 与 lib/features/settings/settings_screen.dart 的 versionLabel
# 2. 提交并推送
# 3. 打 tag 触发发布
git tag v0.2.4 && git push origin v0.2.4
```

本地构建：

```shell
flutter build apk --release          # Android APK（需 android/key.properties）
flutter build macos --release        # macOS 应用
```

## 构建工具链 / Toolchain

Flutter 3.47 默认使用 AGP 9.1.0，但稳定版 `flutter_inappwebview`（6.1.5）的
Android 子包仍引用 AGP 9 已删除的 `proguard-android.txt`，而其 beta 版的 macOS
子包在 Swift 6 下编译不过。因此本项目**固定使用**以下工具链（偏离 Flutter 默认，
但满足 Flutter 3.47 的 Gradle ≥ 8.14 / Kotlin ≥ 2.2.20 下限）：

| 组件 | 版本 | 说明 |
| --- | --- | --- |
| Android Gradle Plugin | `8.13.2` | 8.x 仍保留 `proguard-android.txt`，且支持 compileSdk 36 |
| Gradle | `8.14.2` | Flutter 3.47 最低要求 8.14 |
| Kotlin | `2.2.20` | Flutter 3.47 最低要求 2.2.20 |
| flutter_inappwebview | `6.1.5`（精确锁定） | 稳定版；不要升到 `6.2.0-beta`（macOS 会编译失败） |

这些值位于 `android/settings.gradle.kts`、`android/gradle/wrapper/gradle-wrapper.properties`
与 `pubspec.yaml`。升级插件或 Flutter 版本前，需先确认 `flutter_inappwebview`
的 Android/macOS 子包与新的 AGP/Swift 工具链兼容。

## 项目结构 / Project Structure

```text
lib/
  main.dart                    应用入口、代理注入、ProviderScope
  app/                        AppShell、主题、路由
  core/
    auth/                      登录态、会话恢复、登出、WebView OAuth 桥接
    data/                      统一数据访问层（官方 API + 网页抓取回退）
    diagnostics/               文件日志、全局错误捕获
    feed/                      分页信息流控制器
    l10n/                      中英文案与语言状态
    network/                   代理检测、浏览器打开、动态代理 Dio
    runtime/                   DAKit 组合根
    search/                    搜索历史持久化
  features/
    login/                     登录页
    home/                      内嵌网页首页（WebView）
    search/                    搜索
    artwork/                   作品详情、媒体播放、下载、收藏
    artist/                    作者资料、画廊、收藏夹、关注
    favourites/                当前账户收藏
    watching/                  关注用户列表
    downloads/                 下载记录
    settings/                  设置、代理、语言、日志、关于
    diagnostics/               日志与诊断页
    splash/                    启动页
  shared/widgets/              通用作品卡片、空态/错误态
android/
macos/
windows/
test/
```

## 首页与登录态 / Home & sign-in state

首页内嵌的是 DeviantArt 网页版首页。它的个性化推荐（`rfy/deviations`）由
**网页登录态（Cookie + CSRF）** 驱动，官方 OAuth API 不提供等价接口——这是首页
采用 WebView 的原因。

App 里有两条独立的登录态：

- **网页登录态**：存在首页 WebView 的 Cookie 里，决定首页推荐是否个性化；
- **App OAuth 登录态**：决定收藏 / 关注 / 下载是否可用。

两者不同步时，首页顶部会显示提示条：

- 网页已登录、App 未登录 → 点「登录」直接在 WebView 内完成 OAuth 授权（复用网页
  登录态，无需重输密码）；
- App 已登录、网页未登录 → 点「登录网页版」跳转网页登录页。

OAuth 授权优先在首页 WebView 内完成；WebView 不可用时自动回退系统浏览器。

## 说明 / Notes

- `DAViewer` 是第三方客户端，与 DeviantArt 无隶属关系；
- 客户端不保存 `client_secret`；
- OAuth 授权优先在应用内 WebView 完成（复用网页登录态），系统浏览器作为回退；
  不内置账号密码表单。
