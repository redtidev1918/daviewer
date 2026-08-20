# dA Viewer

一个基于 [DAKit](https://github.com/redtidev1918/dakit) 的第三方 DeviantArt 客户端。

当前版本是可运行的 Flutter 桌面/移动客户端骨架：支持登录、查看当前账户和首页作品列表。

## 与 DAKit 的关系

`dA Viewer` 是应用，DAKit 是 SDK。客户端只依赖 DAKit，不复制 SDK 代码。

本地开发时通过 `path` 依赖使用 DAKit：

```yaml
dependencies:
  dakit_core:
    path: ../dakit/packages/dakit_core
  dakit_api:
    path: ../dakit/packages/dakit_api
  dakit_flutter:
    path: ../dakit/packages/dakit_flutter

dependency_overrides:
  dakit_core:
    path: ../dakit/packages/dakit_core
  dakit_api:
    path: ../dakit/packages/dakit_api
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
  main.dart            应用入口、登录与首页骨架
android/
macos/
windows/
test/
```

## 说明

- `dA Viewer` 是第三方客户端，与 DeviantArt 无隶属关系；
- 客户端不保存 `client_secret`；
- 登录在系统浏览器完成，不内置 WebView 或账号密码表单。
