# 循环计时网页版

这是原生 SwiftUI 应用的独立 PWA 版本，使用原生 HTML、CSS 和 JavaScript，不需要构建依赖。手机上可添加到主屏幕；首次在线访问后可离线打开。项目和历史记录保存在当前浏览器中，可在“设置”里导出、导入备份。原生 App 或模拟器的数据不会自动同步到网页版。

锁屏或切到后台后，iOS 可能暂停网页脚本。再次打开时会根据实际时间校正计时，但网页版不能保证锁屏时准点发声或震动。需要可靠的锁屏提醒时使用原生应用。

本地预览：在本目录运行 `python3 -m http.server 4173`，访问 `http://localhost:4173/`。计时核心与界面烟雾测试可用 JavaScriptCore 的 `jsc -m tests.mjs`、`jsc -m test-ui.mjs` 运行。在部分 macOS 上，`jsc` 需要使用 `/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc` 完整路径。

运行 `python3 build.py` 生成 `dist/` 和 `cycle-timer-pages.zip`。可以将生成的 ZIP 上传到 Cloudflare Pages Direct Upload，或将静态文件部署到支持静态资源的 Cloudflare Worker。部署包是生成产物，不需要提交到 GitHub。在 iPhone Safari 中打开 HTTPS 地址，使用“分享 → 添加到主屏幕”。
