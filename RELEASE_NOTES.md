# Release notes

这里仅记录下载者需要知道的变化和安装提示。内部实现、调试过程、协议细节与测试日志请写入
`CHANGELOG.md` 或 `docs/`，不要放进 GitHub Release。

## 0.2.137

### 更新内容

- 登录页现在只有“社交账号”和“DeviantArt 账号”两个入口，不再显示几个实际效果相同的按钮。
- 修复 Google 登录首次白屏、需要登录两次，以及返回 App 后一直等待的问题。
- 社交账号入口现在支持 DeviantArt 登录页提供的 Google、Apple 和 Facebook。
- 登录页会说明 App 代理与系统浏览器代理的区别，避免网络设置不一致时反复失败。
- 修复 Windows 浏览器登录完成后不能返回已打开客户端的问题。

### macOS

macOS 版本仍是未签名测试版，首次启动可能被系统拦截。请在 Finder 中右键点击
DAViewer，选择“打开”。如果你不接受未签名软件，请不要安装此版本。

### What's new

- The sign-in screen now has two clear choices—social account or DeviantArt account—instead of several buttons that behaved the same way.
- Fixed the first Google sign-in opening a blank page, requiring a second attempt, or leaving the app waiting indefinitely.
- Social sign-in supports the providers offered by DeviantArt, including Google, Apple and Facebook.
- The sign-in screen now explains when the app proxy and the system browser use different network routes.
- Fixed the Windows app not reopening after browser sign-in completes.

### macOS

The macOS download is still an unsigned test build and may be blocked on first
launch. In Finder, right-click DAViewer and choose **Open**. Do not install this
build if you are not comfortable running unsigned software.
