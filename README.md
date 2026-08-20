# DA Viewer

一个基于 [DAKit](https://github.com/redtidev1918/dakit) 的第三方 DeviantArt 客户端。

当前版本是可运行的 Flutter 桌面/移动客户端，支持登录、首页/搜索、作品详情、
原图后台下载、作者画廊/收藏夹、当前账户收藏与下载记录。

## 与 DAKit 的关系

`DA Viewer` 是应用，DAKit 是 SDK。客户端只依赖 DAKit，不复制 SDK 代码。

DAKit 已发布到 pub.dev，客户端直接使用版本化依赖：

```yaml
dependencies:
  dakit_flutter: ^0.1.0
```

## 使用前准备

1. 有一个 DeviantArt 账号；
2. 注册一个 Public OAuth 应用，并准备 `client_id`；
3. 在该应用白名单中精确加入：

```text
dakit://oauth/callback
```

## 运行

```shell
flutter pub get
flutter run -d macos --dart-define=DAKIT_CLIENT_ID=你的_PUBLIC_CLIENT_ID
```

Android：

```shell
flutter run -d android --dart-define=DAKIT_CLIENT_ID=你的_PUBLIC_CLIENT_ID
```

Windows：

```powershell
flutter run -d windows --dart-define=DAKIT_CLIENT_ID=你的_PUBLIC_CLIENT_ID
```

## 代理

如果你需要代理访问 `pub.dev` 或 GitHub，记得 `flutter pub get` 走 Dart HTTP 客户端，不是 Git 代理：

```shell
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export no_proxy=localhost,127.0.0.1
flutter pub get
```

如果 DAKit 使用 Git 依赖，还需要：

```shell
git config --local http.proxy http://127.0.0.1:7890
```

## 项目结构

```text
lib/
  main.dart                    应用入口与 ProviderScope
  app/                        AppShell、主题、路由
  core/
    runtime/                   DAKit 组合根
    auth/                      登录态、会话恢复、登出
  features/
    auth/                      登录页
    home/                      首页信息流
    search/                    搜索
    artwork/                   作品详情与后台下载
    artist/                    作者资料、画廊、收藏夹
    favourites/                当前账户收藏
    downloads/                 下载记录
  shared/widgets/              通用作品卡片
android/
macos/
windows/
test/
```

## 说明

- `DA Viewer` 是第三方客户端，与 DeviantArt 无隶属关系；
- 客户端不保存 `client_secret`；
- 登录在系统浏览器完成，不内置 WebView 或账号密码表单。
