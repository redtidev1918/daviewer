# Release notes

这里仅记录下载者需要知道的变化和安装提示。内部实现、调试过程、协议细节与测试日志请写入
`CHANGELOG.md` 或 `docs/`，不要放进 GitHub Release。

## 0.2.138

### 更新内容

- 登录页现在只有一个「登录或注册」入口。打开官方页后，可以选择
  DeviantArt 账号或页面当前提供的 Google、Apple、Facebook。
- 修复 Google 登录成功后首页还要再登录一次的问题。回到 DAViewer 后，推荐、
  收藏、关注和下载立即使用同一份登录。
- 失效的旧登录现在会恢复为未登录状态并显示登录入口，不再让首页保持假登录态并无限重试。
- 密码和人机验证只在系统浏览器中处理，App 不再将官方安全页误报为网络故障。
- 网络页现在会分别说明 App 代理和系统浏览器代理，避免连通性测试给出错误承诺。
- 日志页不再把内部应用标识当作产品名显示。
- macOS 不再读取会弹出系统密码框的旧钥匙串项目。旧版升级后需要重新登录一次，
  但下载、设置等本地数据不会丢失；之后的更新使用稳定预览身份保持登录。

### macOS

macOS 版本仍是未经过 Apple 签名和公证的测试版，首次启动可能被系统拦截。请在
Finder 中右键点击 DAViewer，选择「打开」。它不会要求你的 Mac 登录密码；如出现
此类请求请直接拒绝。如果你不接受这种测试版，请不要安装。

### What's new

- Sign-in now has one **Sign in or create an account** action. Choose a
  DeviantArt account or any Google, Apple, or Facebook option currently offered
  by the official page.
- Fixed Google sign-in returning to Home and then asking for another web login.
  Recommendations, favourites, watch, and downloads now share the same session.
- An expired saved session now returns to signed-out state with a clear sign-in
  action instead of leaving Home in a false signed-in state with endless retries.
- Passwords and human verification remain in the system browser; the app no
  longer mislabels an official security page as a network failure.
- Network settings now distinguish the App proxy from the system browser proxy
  instead of claiming one connectivity test covers both.
- Diagnostics no longer displays an internal application identifier as the
  product name.
- macOS no longer queries the legacy Keychain item that could display a system
  password prompt. Upgrading from an older preview needs one fresh sign-in,
  while downloads and settings remain; later updates use a stable preview
  identity to preserve the session.

### macOS

The macOS download is still not Apple-signed or notarized and may be blocked on
first launch. In Finder, right-click DAViewer and choose **Open**. It does not
ask for your Mac login password; deny any such request. Do not install this
preview if you are not comfortable with that status.

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
