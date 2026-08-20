# DA Viewer

一个基于 [DAKit](https://github.com/redtidev1918/dakit) 的第三方 DeviantArt 客户端。

当前版本是可运行的 Flutter 桌面/移动客户端，支持 OAuth 登录、首页/每日推荐/关注信息流、
搜索（含历史记录）、作品详情（图片/视频/GIF 播放、富文本简介）、原图下载（含全尺寸预览回退）、
收藏与关注用户、作者画廊/收藏夹、下载记录，以及中英双语切换。

## 与 DAKit 的关系

`DA Viewer` 是应用，DAKit 是 SDK。客户端只依赖 DAKit，不复制 SDK 代码。

DAKit 已发布到 pub.dev，客户端直接使用版本化依赖：

```yaml
dependencies:
  dakit_flutter: ^0.1.0
```

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
flutter run -d macos
```

Android：

```shell
flutter run -d android
```

Windows：

```powershell
flutter run -d windows
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

推送到 `main` 会触发 CI 的质量检查与 Android/macOS 构建；打 `v*` 标签会自动创建
GitHub Release 并上传构建产物。

本地构建：

```shell
flutter build apk --release          # Android APK
flutter build macos --release        # macOS 应用
```

## 项目结构

```text
lib/
  main.dart                    应用入口、代理注入、ProviderScope
  app/                        AppShell、主题、路由
  core/
    auth/                      登录态、会话恢复、登出
    data/                      统一数据访问层（官方 API + 网页抓取回退）
    diagnostics/               文件日志、全局错误捕获
    feed/                      分页信息流控制器
    l10n/                      中英文案与语言状态
    network/                   代理检测、浏览器打开、动态代理 Dio
    runtime/                   DAKit 组合根
    search/                    搜索历史持久化
  features/
    login/                     登录页
    home/                      首页 / 每日推荐 / 关注信息流
    search/                    搜索
    artwork/                   作品详情、媒体播放、下载、收藏
    artist/                    作者资料、画廊、收藏夹、关注
    favourites/                当前账户收藏
    watching/                  关注用户列表
    downloads/                 下载记录
    settings/                  设置、代理、语言、日志
    diagnostics/               日志与诊断页
    splash/                    启动页
  shared/widgets/              通用作品卡片、空态/错误态
android/
macos/
windows/
test/
```

## 说明

- `DA Viewer` 是第三方客户端，与 DeviantArt 无隶属关系；
- 客户端不保存 `client_secret`；
- 登录在系统浏览器完成，不内置 WebView 或账号密码表单。
