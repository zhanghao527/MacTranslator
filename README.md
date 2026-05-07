# Mac Translator

一个轻量的 macOS 划词翻译 App，灵感来自 Bob。纯 Swift + SwiftUI/AppKit，零第三方依赖。

## 功能

- 菜单栏常驻，不占 Dock
- 全局快捷键 `⌥ + D` 读取当前选中文本并翻译
- 自动识别方向：中文 → 英文，其他 → 中文
- 结果浮窗显示在鼠标附近，支持一键复制
- 翻译引擎：Google 免费接口（零配置）

## 构建 & 安装

要求：macOS 13+、Xcode Command Line Tools。

```bash
# 构建并打包成 .app
./build.sh

# 构建后立即启动
./build.sh run

# 安装到 /Applications
./build.sh install
```

产物：`build/MacTranslator.app`

## 首次授权（必做）

App 需要读取其他应用中选中的文本，必须开启「辅助功能」权限：

1. 启动 `MacTranslator.app`（第一次会弹权限提示）
2. 打开「系统设置 → 隐私与安全性 → 辅助功能」
3. 把 MacTranslator 加进去并勾选
4. **完全退出 App 再重新启动**（macOS 权限变更必须重启进程才生效）

## 使用

1. 在任意 App（浏览器、备忘录、IDE…）里选中一段文字
2. 按 `⌥ + D`
3. 鼠标附近弹出浮窗显示译文
4. 点浮窗右上角的复制按钮把译文放到剪贴板

## 项目结构

```
Sources/MacTranslator/
├── main.swift                    # 入口，创建 NSApplication
├── AppDelegate.swift             # 菜单栏 + 快捷键注册 + 主流程
├── GlobalHotkey.swift            # Carbon RegisterEventHotKey 封装
├── SelectionReader.swift         # 通过模拟 ⌘C 读取选中文本
├── Translator.swift              # Google 免费翻译接口
└── TranslationPopupWindow.swift  # SwiftUI 结果浮窗
```

## 常见问题

**按快捷键没反应**
99% 是辅助功能权限没给，或者给完没重启 App。

**显示「未读取到选中文本」**
- 当前 App 不响应 ⌘C（部分游戏、受保护的密码框）
- 先在系统偏好设置把 MacTranslator 的辅助功能权限打开

**翻译失败 / 超时**
Google 免费接口在国内网络可能不稳。可以稳定代理，或后续扩展 Translator 接入其他引擎（DeepL、OpenAI、macOS 系统翻译都可）。

**快捷键和别的 App 冲突**
目前快捷键写死在 `AppDelegate.registerHotkey()`（keyCode 0x02 = `D`）。改一下就行。

## 后续可以加的功能

- [ ] 偏好设置窗口（自定义快捷键、目标语言、引擎）
- [ ] 多引擎（macOS 原生 Translation、DeepL、OpenAI、Ollama 本地模型）
- [ ] 输入框翻译模式（不依赖选中）
- [ ] 翻译历史
- [ ] 截图 OCR 翻译（Vision 框架）
