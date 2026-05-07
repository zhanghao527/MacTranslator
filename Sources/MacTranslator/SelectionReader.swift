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
        pasteboard.clearContents()

        // 发送 ⌘ + C
        sendCommandC()

        // 等待剪贴板更新，最多 300ms
        let deadline = Date().addingTimeInterval(0.3)
        while Date() < deadline {
            if pasteboard.changeCount != oldChangeCount + 1 && pasteboard.changeCount != oldChangeCount {
                // changeCount 变过了
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }

        let copied = pasteboard.string(forType: .string)

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

        return copied
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
