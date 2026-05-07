import AppKit
import Carbon.HIToolbox

/// 读取当前前台 App 中用户选中的文本。
/// 做法：模拟发送 ⌘C，等剪贴板更新，读出后还原原有剪贴板内容。
enum SelectionReader {
    static func currentSelection() -> String? {
        let pasteboard = NSPasteboard.general

        // 备份原有剪贴板
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        } ?? []

        let oldChangeCount = pasteboard.changeCount

        // 发送 ⌘ + C 给前台 App
        sendCommandC()

        // 等待剪贴板 changeCount 变化，最多 400ms
        let deadline = Date().addingTimeInterval(0.4)
        var changed = false
        while Date() < deadline {
            if pasteboard.changeCount != oldChangeCount {
                changed = true
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }

        let copied = pasteboard.string(forType: .string)

        if !changed {
            NSLog("[MacTranslator] SelectionReader: clipboard changeCount 未变化 — 很可能辅助功能权限未生效，或前台 App 不响应 ⌘C")
        } else if copied == nil || copied?.isEmpty == true {
            NSLog("[MacTranslator] SelectionReader: 剪贴板变化了但取不到字符串")
        } else {
            NSLog("[MacTranslator] SelectionReader: 读取到 \(copied!.count) 字")
        }

        // 还原剪贴板
        pasteboard.clearContents()
        if !savedItems.isEmpty {
            let restored: [NSPasteboardItem] = savedItems.map { dict in
                let item = NSPasteboardItem()
                for (type, data) in dict {
                    item.setData(data, forType: type)
                }
                return item
            }
            pasteboard.writeObjects(restored)
        }

        // 没检测到复制动作就返回 nil，避免把旧剪贴板内容当成"选中文本"
        return changed ? copied : nil
    }

    private static func sendCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeC: CGKeyCode = 0x08 // 'c'

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCodeC, keyDown: true)
        let up   = CGEvent(keyboardEventSource: source, virtualKey: keyCodeC, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand

        let loc = CGEventTapLocation.cghidEventTap
        down?.post(tap: loc)
        up?.post(tap: loc)
    }
}
