# 发布说明 / Release notes

这里只写下载者需要知道的变化，一行一条。内部实现、协议与调试细节请见
`CHANGELOG.md`。

## 0.2.162

- 网络异常时不再把已登录状态误显示为未登录。
- 标签排序「最新 / 热门」现在真正生效（之前返回相同结果）。
- 搜索页：最近搜索移到最上面，并改为紧凑的标签样式。
- 「为你推荐」标签会记住你看过的作品，重启后仍然可用。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Sign-in is no longer shown as signed-out when the network is unavailable.
- Tag sorting (Newest / Popular) now actually differs.
- Search: recent searches moved to the top as compact chips.
- “Recommended for you” tags persist your viewing interests across restarts.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.161

- 搜索页「为你推荐」标签也显示作品预览图，按你的兴趣排序（最感兴趣的在最前）。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- “Recommended for you” tags on the search page now show artwork previews, ordered by your interests.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.160

- 更新提醒更灵敏：新版本发布后能更快看到提示（每小时检查 + 回到前台时检查）。
- 搜索页热门标签现在带作品预览图（Pixiv 风格）。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Update reminders appear sooner (hourly + on return to foreground).
- Popular tags on the search page now show an artwork preview (Pixiv style).

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.159

- 标签页新增「最新 / 热门」排序；搜索结果新增「最新优先」排序。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Tag pages now sort by Newest or Popular; search results can be ordered newest-first.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.158

- 作品卡片的标题和作者名移到图片下方，不再遮挡图片。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Artwork card titles and author names now sit below the image instead of covering it.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.157

- 修复通过链接打开作品报错的问题（数字链接现在能正常打开详情，含 R18）。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Fixed opening artworks from pasted links (numeric links now load the detail page, including R18).

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.156

- 修复通过链接打开 R18 作品时报错「api endpoint not found」的问题。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Fixed “api endpoint not found” when opening an R18 artwork from a pasted link.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.155

- 关注动态顶部会显示更多关注用户，不再只有零星几个。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- The Watched tab now surfaces many more watched artists at the top.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.154

- 登录成功后立即显示「登录成功」界面（正在同步登录状态），不再停留在登录页让首次用户困惑。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Shows a “Signed in — syncing your session” screen right after sign-in instead of lingering on the login page.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.153

- 修复登录状态偶尔在重启后丢失、又要重新登录的问题。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Fixed the sign-in occasionally being lost after a restart (no more forced re-login).

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.152

- 进一步优化登录页弹出键盘时的卡顿。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Further reduced sign-in page lag when the keyboard opens.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.151

- 登录成功时显示「登录成功」提示。
- 登录失败时在登录页显示具体原因，不再静默失败。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Shows a “Signed in” toast after a fresh sign-in.
- Sign-in failures now display the reason on the login page instead of failing silently.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.150

- 修复重启后又要重新登录的问题：登录状态现在会在下次打开时恢复。
- 推荐流在登录会话过期时会自动刷新并重试，不再一直转圈。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Fixed having to sign in again after restarting the app; the session is restored on the next launch.
- Recommendations now refresh their session and retry instead of spinning forever.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.149

- 修复登录完成后出现黑屏的问题。
- 登录页增加提示：如页面出现人机验证，请按页面提示完成。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Fixed the black screen appearing after sign-in completes.
- Sign-in now shows a hint when a human-verification challenge appears.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.148

- 修复登录后「推荐」不显示、点击登录一直跳回首页的问题。
- 修复从「关注动态」等标签页登录后没有回到原页面的问题。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Fixed recommendations not appearing after sign-in (tapping sign-in kept bouncing back to Home).
- Fixed sign-in from the Watched tab returning to the wrong page.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.147

- 修复登录页弹出键盘时卡顿、掉帧的问题。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Fixed the sign-in page lagging and dropping frames when the keyboard opens.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.146

- 修复 Android 版本点击后闪退、打不开的问题（包名变更后主界面类未同步迁移）。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Fixed the Android build crashing on launch (the entry activity wasn't moved to the new package name).

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.145

- 首页新增轻量更新提醒：有新版本时显示可关闭的提示条，被忽略的版本不再打扰。
- 「日志与诊断」页新增「报告问题」：在你的浏览器里打开预填好的 GitHub Issue，可选附带脱敏日志；App 不会自动上传任何数据。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Home now shows a slim, dismissible banner when a newer version is available; ignored versions won't nag again.
- Diagnostics gains “Report a problem”: opens a pre-filled GitHub issue in your browser with an optional redacted log; the app never uploads anything automatically.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.144

- 首页「推荐」恢复为网页版个性化推荐流，与官网推荐一致。
- 清理登录与网络设置中残留的“系统浏览器”旧文案。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Home “For you” is back to the website's personalized recommendation feed.
- Removed stale “system browser” wording from sign-in and network settings.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.143

- 作者主页、画廊分组、收藏集和标签页现在都能直接分享。
- 修复退出登录或切换账号后，首页、收藏和通知仍显示上一账号内容的问题。
- 登录失败时给出可执行的提示，不再显示 “Unable to access” 之类的内部错误。
- 已登录用户误入登录页时会自动回到首页。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Share is now available from the artist, gallery folder, collection, and tag screens.
- Fixed stale content from a previous account remaining after logout or account switch.
- Login failures now show actionable guidance instead of internal errors like “Unable to access”.
- A signed-in user who lands on the login screen is sent back to Home.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.142

- 登录回到应用内网页：打开官方登录页一次即可，Google、Apple 等入口都在页面上。
- 支持分享作品、画师、画廊分组、收藏集和标签的公开链接。
- 首页「推荐」更正为「发现」：这是官方通用发现流。
- 应用标识改为中性名称：需卸载旧版后重新安装，并重新登录一次。

> macOS 包未经过 Apple 签名和公证，仅供测试；首次启动请在 Finder 中右键选择「打开」。

- Sign-in is back in-app: open the official login page once — Google, Apple, and other options are right on the page.
- Share public links for artworks, artists, gallery folders, collections, and tags.
- Home “For you” is renamed “Discover”: it is the official generic discovery feed.
- The app identifier is now neutral: uninstall the old build, reinstall, and sign in again.

> The macOS build is not Apple-signed or notarized. On first launch, right-click it in Finder and choose Open.

## 0.2.141

- 支持分享作品、画师、画廊分组、收藏集和标签；首页「推荐」更正为「发现」。

- Share public links for artworks, artists, gallery folders, collections, and tags; Home “For you” renamed “Discover”.

## 0.2.139

- 登录回到应用内网页：一次登录即可用于首页、收藏、关注和下载。

- Sign-in is back in-app: one sign-in covers Home, favourites, watch, and downloads.

## 0.2.138

- 登录改为单个入口，页面提供 Google、Apple、Facebook；登录一次即可用于首页、收藏、关注和下载。
- 失效登录自动恢复为未登录状态；网络设置区分 App 代理与系统浏览器代理。
- macOS 修复旧钥匙串弹出密码框的问题（升级后需重新登录一次）。

- Sign-in is now a single action with Google, Apple, and Facebook on the page; one sign-in covers Home, favourites, watch, and downloads.
- Expired sessions return to signed-out; network settings separate app and browser proxies.
- macOS no longer triggers the legacy Keychain password prompt (sign in again once after upgrade).

## 0.2.137

- 登录页入口去重；修复 Google 登录白屏、需登录两次和返回后一直等待的问题。
- 网络设置区分 App 代理与系统浏览器代理；修复 Windows 浏览器登录后无法返回客户端的问题。

- Deduplicated the sign-in actions; fixed Google sign-in showing a blank page, requiring a second attempt, or leaving the app waiting.
- Network settings distinguish app and browser proxies; fixed the Windows app not reopening after browser sign-in.
