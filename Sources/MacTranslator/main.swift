import AppKit

// 必须手动创建 NSApplication 实例（SwiftPM 可执行文件不会自动创建）
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 菜单栏 App，不在 Dock 里显示
app.setActivationPolicy(.accessory)
app.run()
