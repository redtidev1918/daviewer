# DAViewer

**语言 / Language:** 中文 · [English](README.en.md)

> DeviantArt 官方放弃了他们的移动 App，社区没有一个像样的第三方客户端。
> 于是有了 **DAViewer** —— 一个基于 [DAKit](https://github.com/redtidev1918/dakit) 的开源
> DeviantArt 客户端，把官网体验原汁原味地带回桌面和手机。

[![GitHub stars](https://img.shields.io/github/stars/redtidev1918/daviewer?style=flat&color=yellow)](https://github.com/redtidev1918/daviewer/stargazers)
[![GitHub license](https://img.shields.io/github/license/redtidev1918/daviewer?style=flat)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/redtidev1918/daviewer?style=flat)](https://github.com/redtidev1918/daviewer/releases)
[![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20macOS%20%7C%20Windows-blue?style=flat)](https://github.com/redtidev1918/daviewer/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.1-blue?style=flat&logo=flutter)](https://flutter.dev)

## 为什么做这个项目

- DeviantArt 官方 **已下架/停止维护** 其客户端 App，第三方工具也大多停更；
- 网页版功能齐全（个性化推荐、画廊、标签、收藏、关注、下载），但缺少桌面/移动
  原生体验；
- 本项目把网页版的完整能力 + 原生交互组合起来，开箱即用，无需自己注册 OAuth 应用。

## 功能特性

- **登录**：一次登录同时完成网页会话 + OAuth（内置公开 client id，开箱即用，无需注册 OAuth 应用）
- **推荐流**：首页「推荐」为网页版个性化推荐（`rfy/deviations`），与官网一致
- **搜索**：关键词搜索 + 历史记录 + 粘贴 DeviantArt 链接直达作品/作者
- **作品详情**：图片 / 视频（可拖进度）/ GIF 播放，多图作品左右翻页，完整富文本简介（链接 / 加粗 / 表情 / 内嵌图片）
- **标签**：详情页显示 `#标签`，可点击进入标签作品流，标签页带「相关标签」推荐
- **作者**：资料（含作者简介）、画廊、**自定义分画廊（画集）**、收藏夹、关注
- **社交**：收藏作品（显示收藏态）、关注/取消关注作者、关注用户列表、通知（谁更新了作品）
- **下载**：原图后台下载，受限时回退全尺寸预览；下载记录支持打开文件/文件夹
- **双语**：中文 / English 切换
- **代理**：自动检测系统代理 + 手动配置（国内访问必需）

## 与 DAKit 的关系

`DAViewer` 是应用，DAKit 是 SDK。客户端只依赖 DAKit，不复制 SDK 代码。
DAKit 已发布到 pub.dev，客户端直接使用版本化依赖：

```yaml
dependencies:
  dakit_flutter: ^0.1.0
```

## 安装

从 [Releases](https://github.com/redtidev1918/daviewer/releases) 下载对应平台的安装包：

- **Android**：`DAViewer-<版本>.apk`
- **macOS**：`DAViewer-<版本>-macos.zip`（解压后拖入「应用程序」）
- **Windows**：`DAViewer-<版本>-windows.zip`（解压后运行 `DAViewer.exe`）

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

## 运行

```shell
flutter pub get
flutter run -d macos     # macOS
flutter run -d android   # Android
flutter run -d windows   # Windows
```

## 代理

应用运行时会自动读取系统代理（macOS 通过 `scutil`，Windows 通过注册表）。若需手动指定，
可在「设置 → 网络代理」中填写 `host:port`。

`flutter pub get` 走 Dart HTTP 客户端，不走 Git 代理；如需代理访问 pub.dev：

```shell
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export no_proxy=localhost,127.0.0.1
flutter pub get
```

## 构建 Release

推送到 `main` 会触发 CI 的质量检查与 Android/macOS/Windows 构建；打 `v*` 标签会自动创建
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
git tag v0.2.42 && git push origin v0.2.42   # 替换为实际版本号
```

本地构建：

```shell
flutter build apk --release          # Android APK（需 android/key.properties）
flutter build macos --release        # macOS 应用
flutter build windows --release      # Windows 应用
```

## 构建工具链

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

## 项目结构

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
    home/                      首页（原生三标签：推荐 / 每日推荐 / 关注）
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

## 首页与登录态

首页是**原生界面**（推荐 / 每日推荐 / 关注 三个标签）。其中「推荐」流的数据来自
DeviantArt 网页版的个性化接口（`rfy/deviations`），官方 OAuth API 不提供等价
接口，因此它需要**网页登录态（Cookie + CSRF）**。

App 里存在两条独立的登录态：

- **网页登录态**：由内置 WebView 建立（Cookie + CSRF），决定首页「推荐」是否个性化；
  冷启动时会静默刷新，无需每次手动登录。
- **App OAuth 登录态**：决定收藏 / 关注 / 下载是否可用。

两者不同步时，首页顶部会显示提示条，一键补全。OAuth 授权优先在内置 WebView 内
完成（复用网页登录态，无需重输密码），WebView 不可用时自动回退系统浏览器。

## 贡献

欢迎任何形式的贡献 —— 提 Issue、修 Bug、加功能、完善文档都行。详见
[CONTRIBUTING.md](CONTRIBUTING.md)。安全漏洞请走 [SECURITY.md](SECURITY.md)，
社区准则见 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

1. Fork 本仓库，从 `main` 开分支；
2. 改动后 `flutter analyze` 通过即可提交；
3. 发 PR 描述清楚「改了什么、为什么」。

客户端依赖的 SDK 是 [DAKit](https://github.com/redtidev1918/dakit)（已发布到
pub.dev），涉及 SDK 的改动请到那边提 PR，两边一起发布。

如果觉得这个项目有用，**点个 ⭐ Star** 能让它被更多人看到。

## 说明

- `DAViewer` 是第三方客户端，与 DeviantArt 无隶属关系；
- 客户端不保存 `client_secret`；
- OAuth 授权优先在应用内 WebView 完成（复用网页登录态），系统浏览器作为回退；
  不内置账号密码表单。
