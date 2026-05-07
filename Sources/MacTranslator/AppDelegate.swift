import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popupWindow: TranslationPopupWindow?
    private let hotkey = GlobalHotkey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        registerHotkey()
        checkAccessibilityPermission()
    }

    // MARK: - 菜单栏

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // 用 SF Symbol 做图标
            if let image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Translate") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "译"
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "划词翻译 (⌥D)", action: #selector(triggerTranslate), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "检查辅助功能权限", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Mac Translator"
        alert.informativeText = "轻量级划词翻译工具\n\n快捷键：⌥ + D\n引擎：Google 免费接口\n\n首次使用需在【系统设置 → 隐私与安全性 → 辅助功能】授权。"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 快捷键

    private func registerHotkey() {
        // ⌥ + D
        hotkey.register(keyCode: 0x02, modifiers: [.option]) { [weak self] in
            self?.triggerTranslate()
        }
    }

    @objc private func triggerTranslate() {
        // 每次触发都检查一次权限，没权限直接提示用户
        if !AXIsProcessTrusted() {
            showPopup(withText: "（辅助功能权限未开启）",
                      translation: "请到「系统设置 → 隐私与安全性 → 辅助功能」开启 MacTranslator，然后退出 App 重启。",
                      originalText: "")
            return
        }

        guard let text = SelectionReader.currentSelection()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            showPopup(withText: "（未读取到选中文本）",
                      translation: "请先选中文字再按快捷键。如果权限刚授予，请退出 App 重启一次（ad-hoc 签名的 App 权限每次重新打包都需要重授）。",
                      originalText: "")
            return
        }
        showPopup(withText: text, translation: nil, originalText: text)
        Task {
            do {
                let result = try await Translator.shared.translate(text: text)
                await MainActor.run {
                    self.showPopup(withText: text, translation: result, originalText: text)
                }
            } catch {
                await MainActor.run {
                    self.showPopup(withText: text, translation: "翻译失败：\(error.localizedDescription)", originalText: text)
                }
            }
        }
    }

    // MARK: - 弹窗

    private func showPopup(withText source: String, translation: String?, originalText: String) {
        if popupWindow == nil {
            popupWindow = TranslationPopupWindow()
        }
        popupWindow?.show(source: source, translation: translation, originalText: originalText)
    }

    // MARK: - 权限

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            // 弹一个温和提示，不强制跳设置
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "Mac Translator 需要「辅助功能」权限才能读取选中文本。\n\n请在打开的设置页中勾选本 App，然后重启一次。"
                alert.addButton(withTitle: "打开设置")
                alert.addButton(withTitle: "稍后")
                if alert.runModal() == .alertFirstButtonReturn {
                    self.openAccessibilitySettings()
                }
            }
        }
    }
}
