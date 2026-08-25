# DAViewer

<p align="center">
  <img src="assets/icon/icon.png" alt="DAViewer" width="160" />
</p>

**语言 / Language:** 中文 · [English](README.en.md)

> DeviantArt 官方已停止维护其移动客户端。DAViewer 是一个基于
> [DAKit](https://github.com/redtidev1918/dakit) 的开源 DeviantArt 客户端，
> 面向 Android、macOS 与 Windows，以原生应用提供网页版的主要功能。

[![GitHub stars](https://img.shields.io/github/stars/redtidev1918/daviewer?style=flat&color=yellow)](https://github.com/redtidev1918/daviewer/stargazers)
[![GitHub license](https://img.shields.io/github/license/redtidev1918/daviewer?style=flat)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/redtidev1918/daviewer?style=flat)](https://github.com/redtidev1918/daviewer/releases)
[![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20macOS%20%7C%20Windows-blue?style=flat)](https://github.com/redtidev1918/daviewer/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.1-blue?style=flat&logo=flutter)](https://flutter.dev)

## 安装

从 [Releases](https://github.com/redtidev1918/daviewer/releases) 下载对应平台的安装包：

- **Android**：`DAViewer-<版本>.apk`
- **macOS 12+ 未签名测试版**：`DAViewer-<版本>-macos-unsigned-preview.zip`
  （同时支持 Intel 与 Apple Silicon；解压后拖入「应用程序」）
- **Windows**：`DAViewer-<版本>-windows.zip`（解压后运行 `DAViewer.exe`）

Windows ZIP 版首次正常启动时，仅在当前用户的
`HKCU\\Software\\Classes\\dakit` 注册 OAuth 回调，用于系统浏览器登录后返回 DAViewer；
不需要管理员权限、不安装服务，也不读取系统密码。移动解压目录后再次启动会更新路径。

> **关于 macOS 版本的说明**：这是明确标记的**未经过 Apple 签名、未公证测试版**，暂未加入 Apple
> 开发者计划。CI 只使用项目自己的稳定预览签名来保持钥匙串身份一致，它不受 Apple 信任，
> 不能绕过 Gatekeeper。首次打开请在 Finder 中右键点 App 图标并选择「打开」。DAViewer
> 不会要求或读取 Mac 登录密码；如果安装包弹出这种请求，请拒绝并报告问题。

## 截图预览

<table align="center">
  <tr>
    <td align="center"><img src="docs/screenshots/home_feed.jpg" width="200" /><br /><sub>首页推荐</sub></td>
    <td align="center"><img src="docs/screenshots/artwork_detail.jpg" width="200" /><br /><sub>作品详情</sub></td>
    <td align="center"><img src="docs/screenshots/related_works.jpg" width="200" /><br /><sub>相关推荐</sub></td>
  </tr>
</table>

## 目录

- [为什么做这个项目](#为什么做这个项目)
- [功能特性](#功能特性)
- [与 DAKit 的关系](#与-dakit-的关系)
- [使用前准备](#使用前准备)
- [运行](#运行)
- [代理](#代理)
- [构建与发布](#构建与发布)
- [首页与登录态](#首页与登录态)
- [登录常见问题](#登录常见问题)
- [贡献](#贡献)
- [说明](#说明)

## 为什么做这个项目

- DeviantArt 官方已停止维护其客户端 App；
- 网页版功能丰富（推荐、画廊、标签、收藏、关注、下载），但缺少桌面/移动原生体验；
- 本项目把网页版的主要功能与原生交互结合起来，开箱即用，无需自己注册 OAuth 应用。

## 功能特性

- **登录**：一个「登录或注册」入口打开系统浏览器中的官方 OAuth/PKCE 页，
  在官方页选择 DeviantArt、Google、Apple 或 Facebook
- **推荐流**：首页「推荐」使用官方 OAuth `browse/home`，登录成功后直接可用
- **搜索**：实时搜索（边输边出结果）+ 历史记录 + 粘贴 DeviantArt 链接直达作品/作者
- **作品详情**：左右滑动或顶部按钮切换前后作品（相邻作品图片预加载）；双指缩放；多图分页
- **媒体**：图片统一缩放；视频最高画质、可拖进度、失败重试；GIF 角标 + 富文本图片带缓存和加载进度
- **相关内容**：详情页原生展示「更多类似作品」、相似画师、已被收录 / 建议收藏集（点击可打开完整内容）、作者更多作品；空结果与失败有明确提示
- **标签**：详情/搜索/标签页统一标签条，缺失标签自动从官方数据补全
- **作者**：资料（含简介）、画廊、自定义分画廊（画集）、收藏夹、关注
- **社交**：收藏（含收藏态）、关注/取关作者、关注列表、通知（未读红点 + 本地已读）
- **下载**：实时确认原图权限；缩略图预览；不可下载时说明原因并降级保存最高画质预览；支持打开文件/文件夹与删除确认
- **外观与设置**：浅色 / 深色 / 跟随系统；语言与外观设置持久化；清除缓存；检查更新
- **双语**：中文 / English 切换
- **网络**：自动检测系统代理、直连测试与可选手动代理；能直连的国际网络无需配置，
  受限网络按实际代理端口设置

## 与 DAKit 的关系

`DAViewer` 是应用，DAKit 是 SDK。客户端只依赖 DAKit，不复制 SDK 代码；OAuth、
官方 API 映射、领域模型与后台传输归 DAKit，网页稀疏数据补全与原生
交互归 DAViewer。依赖版本：

```yaml
dependencies:
  dakit_core: ^0.1.12
  dakit_api: ^0.1.24
  dakit_flutter: ^0.1.9
```

每次登录只创建一个官方 OAuth/PKCE 事务，全部账号选择、密码和人机验证都留在
系统浏览器中。回调后 App 只使用这一份 OAuth 身份，不再要求第二次网页登录。
未登录是正常引导状态。详细边界见 [架构说明](docs/architecture.md)。

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

应用运行时会按「App 手动设置 → 系统代理 → `https_proxy` / `http_proxy` /
`all_proxy` → 构建参数」选择网络路径。「设置 → 网络代理」支持
`127.0.0.1:<你的代理端口>` 或 `http://127.0.0.1:<你的代理端口>`，设置会持久保存，并同时用于 API、
图片、下载和后台公开网页适配器；页面内可直接测试 App 路径的 DeviantArt 连通性。
登录始终使用系统浏览器，因此遵循系统代理或 VPN；App 专用代理无法接管外部浏览器。

这里的端口没有固定值，必须以你的代理软件显示的 HTTP/Mixed 端口为准。在手机上，
`127.0.0.1` 只表示代理也运行在同一部手机；如果代理运行在电脑或路由器，请填写它的
局域网 IP，并开启“允许局域网”。App 会先测试直连：可用则不要求代理，不可用才给出
代理排障，因此国际用户和受限网络用户不会被套用同一条提示。

从 Finder 直接启动通常不会继承终端的 `all_proxy`。macOS 12/13 的 App 内手动代理
无法注入后台网页适配器，因此这两个版本请使用 macOS 系统代理。完整优先级、平台覆盖和排障方式见
[网络与代理说明](docs/networking.md)。

`flutter pub get` 与 Gradle 构建需要代理时的环境变量写法见
[构建说明](docs/build.md#proxying-builds)。

## 构建与发布

推送到 `main` 会触发 CI 的质量检查与 Android/macOS/Windows 构建；打 `v*` 标签会
自动创建 GitHub Release 并上传构建产物（说明取自对应版本的 `RELEASE_NOTES.md` 用户文案）。

**一键发布（推荐）**：Actions → **Release** → Run workflow → 选 `patch` / `minor`
/ `major`（或填具体版本号）→ 运行。它会自动改版本号、提交、推 tag，随后 CI
构建并发布。

本地验证构建：

```shell
flutter build apk --release          # Android APK（需 android/key.properties）
flutter build macos --release        # macOS 应用
flutter build windows --release      # Windows 应用
```

签名、工具链版本（AGP / Gradle / Kotlin / flutter_inappwebview）与 macOS 未签名
标记的细节见 [构建说明](docs/build.md)。

## 首页与登录态

首页是**原生界面**（推荐 / 每日推荐 两个标签），底部另有**「关注动态」一级标签**
（即 DeviantArt 的 `/watch/deviations`，关注画师的最新作品，顶部带按更新时间排序的
头像排）。「推荐」和「每日推荐」都使用官方 OAuth API，与收藏、关注、下载共用
同一份登录态。系统浏览器中的官方页负责账号、注册、社交提供商和安全验证；
`dakit://oauth/callback` 回到 App 后登录就已完成，没有第二份网页身份需要同步。

从 0.2.138 起，macOS 预览包使用稳定的项目签名和新的钥匙串项目，后续升级不应再弹出
Mac 登录密码。为避免静默触发旧版 ad-hoc 钥匙串的可疑密码框，本版不会自动读取旧令牌；
从旧版升级时只需重新走一次官方登录，下载、设置和其他本地数据不会被删除。之后只有明确
没有令牌、令牌被撤销或用户主动退出时才要求重新登录。

## 登录常见问题

- **DAViewer 没有自己的账号**：你登录的是 DeviantArt 官方账号，应用不额外注册账号、不保存密码。
- **忘记密码 / 注册账号**：点「登录或注册」后，统一由 DeviantArt 官方页提供。
- **Google / Apple / Facebook 登录**：统一使用系统安全浏览器打开 DeviantArt 官方 OAuth/PKCE 页，再选择官网当前提供的账号。Google 官方禁止嵌入式 WebView，因此 App 不再伪造 User-Agent 或模拟点击网页按钮。完成后自动回到 App，一次授权即可。
- **社交登录与代理**：系统浏览器遵循系统代理或 VPN；App 中手动填写的代理只覆盖 App 内网络。如果当前是 App 专用代理，登录页会明确提醒先保证系统浏览器也能访问 DeviantArt/对应提供商。
- **登录前检查代理**：原生登录入口会显示当前网络路径，可直接进入代理设置或运行连通性测试，不必等网页白屏后再排查。
- **出现人机验证**：这是官方页或账号提供商的安全流程，直接在系统浏览器里完成。App 不再将 403/429/503 猜测成断网，也不再用易失效的网页控件侦测干预它。
- **登录页没打开或未回到 App**：等待页可重新打开同一授权地址，不会创建第二个 state；取消后才能开始一个全新事务。
- **首次启动与离线恢复**：App 只在本机确实成功保存过 OAuth 会话时，才会在网络或上游暂时失败后保留登录态；从未登录的用户不会被误送进首页，老用户的 token 也不会因临时断网被清除。
- **成人内容**：DeviantArt 的账号浏览偏好优先于 App 请求。可在「设置 → DeviantArt 账号设置 → 成人内容设置」直达修改。
- **登录失败时仍可使用设置**：登录页右上角齿轮可进入语言、网络代理、日志与诊断、检查更新和关于；这些页面不受登录路由限制。
- **macOS 要求输入 Mac 密码**：0.2.138 及之后的包不应出现这种请求。请直接拒绝，不要输入密码，并通过 Issue 报告版本与截图。从更早版本升级会重新登录一次，正是为了不读取会触发该密码框的旧钥匙串项目。

登录与会话恢复的完整状态规则见 [登录与会话说明](docs/authentication.md)。

## 贡献

欢迎任何形式的贡献 —— 提 Issue、修 Bug、加功能、完善文档都行。详见
[CONTRIBUTING.md](CONTRIBUTING.md)。安全漏洞请走 [SECURITY.md](SECURITY.md)，
社区准则见 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

1. Fork 本仓库，从 `main` 开分支；
2. 改动后运行 `dart format lib test`、`flutter analyze` 和 `flutter test`；
3. 发 PR 描述清楚「改了什么、为什么」。

客户端依赖的 SDK 是 [DAKit](https://github.com/redtidev1918/dakit)（已发布到
pub.dev），涉及 SDK 的改动请到那边提 PR，两边一起发布。

如果觉得这个项目有用，**点个 ⭐ Star** 能让它被更多人看到。

## 说明

- `DAViewer` 是第三方客户端，与 DeviantArt 无隶属关系；
- 客户端不保存 `client_secret`；
- 所有账号授权都使用系统浏览器中的 DeviantArt 官方页；App 不内置或读取账号密码表单。
