# 🖼️ DAViewer 文档中心

项目文档索引。面向用户的介绍与安装说明见根目录
[README.md（中文）](https://github.com/redtidev1918/daviewer/blob/main/README.md) 与
[README.en.md（English）](https://github.com/redtidev1918/daviewer/blob/main/README.en.md)；
本站（docs/）存放更深层的开发与架构说明。面向用户页面（本页、下载页）为中文，
开发者文档正文按约定使用英文。

## 📥 下载

Android / Windows / macOS 安装包见 [📥 下载页](download.md)，始终指向最新 Release。

## 文档

- [Architecture — 架构设计](architecture.md)：SDK 与应用边界、作品数据流、相关推荐
  状态、手势所有权、认证、应用内状态与发布约定。
- [Authentication and session recovery — 认证与会话恢复](authentication.md)：
  单 OAuth 模型、冷启动恢复、macOS 钥匙串存储、成人内容设置。
- [Networking and proxy — 网络与代理](networking.md)：运行时优先级、持久化手动设置、
  各平台 WebView 覆盖、连通性测试与恢复。
- [Web adapter — 网页适配器](web_adapter.md)：逆向网页接口的兼容约定（端点注册表、
  回退策略与变更排查手册）。
- [Build notes — 构建与发布](build.md)：固定工具链、Release/CI 约定、pub get 与
  Gradle 构建的代理配置。

参与贡献见 [CONTRIBUTING.md](https://github.com/redtidev1918/daviewer/blob/main/CONTRIBUTING.md)；
安全漏洞请走 [SECURITY.md](https://github.com/redtidev1918/daviewer/blob/main/SECURITY.md)；
社区准则见 [CODE_OF_CONDUCT.md](https://github.com/redtidev1918/daviewer/blob/main/CODE_OF_CONDUCT.md)。

## 相关

- [DAKit 文档](https://github.com/redtidev1918/dakit/blob/main/docs/README.md)：本应用依赖的
  上游 SDK（OAuth、官方 API 映射、领域模型、后台传输）。SDK 相关问题请在那边提出。

## 约定

- 面向用户的页面保持中文，必要时提供中英双语；开发者文档正文用英文。
- 文档只描述当前行为；历史决策见
  [CHANGELOG.md](https://github.com/redtidev1918/daviewer/blob/main/CHANGELOG.md) 与 Release 历史。
