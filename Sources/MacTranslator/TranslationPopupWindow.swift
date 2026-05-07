import AppKit
import SwiftUI

final class TranslationPopupWindow {
    private var window: NSPanel?
    private let viewModel = PopupViewModel()

    /// 监听「在本 App 之外」的点击，用于自动隐藏
    private var globalClickMonitor: Any?
    /// 监听其他 App 激活事件，作为保险
    private var appActivationObserver: NSObjectProtocol?

    func show(source: String, translation: String?, originalText: String) {
        viewModel.source = source
        viewModel.translation = translation
        viewModel.originalText = originalText
        viewModel.isLoading = translation == nil

        if window == nil {
            let hosting = NSHostingController(rootView: PopupView(viewModel: viewModel, onClose: { [weak self] in
                self?.hide()
            }))
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
                styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.isFloatingPanel = false
            // 普通级别：其他 App 的窗口可以正常覆盖它
            panel.level = .normal
            panel.hidesOnDeactivate = false
            panel.contentViewController = hosting
            panel.backgroundColor = NSColor.windowBackgroundColor
            panel.hasShadow = true
            panel.isOpaque = false
            panel.appearance = NSApp.effectiveAppearance
            // 圆角
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.cornerRadius = 10
            panel.contentView?.layer?.masksToBounds = true
            // 切换空间时跟随，关闭时不把窗口进窗口列表
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
            self.window = panel
        }

        positionWindowNearMouse()
        window?.orderFrontRegardless()
        startAutoDismissMonitors()
    }

    func hide() {
        stopAutoDismissMonitors()
        window?.orderOut(nil)
    }

    // MARK: - 位置

    private func positionWindowNearMouse() {
        guard let window = window else { return }
        let mouse = NSEvent.mouseLocation
        let size = window.frame.size
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - size.height - 12)

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
            let vf = screen.visibleFrame
            origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
            origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        }
        window.setFrameOrigin(origin)
    }

    // MARK: - 自动隐藏

    private func startAutoDismissMonitors() {
        stopAutoDismissMonitors()

        // 其他 App 范围内按下鼠标 → 隐藏面板
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.hide()
        }

        // 有其他 App 被激活 → 隐藏面板（保险）
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            let activated = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            // 如果激活的是我们自己，不隐藏
            if activated?.bundleIdentifier == Bundle.main.bundleIdentifier { return }
            self.hide()
        }
    }

    private func stopAutoDismissMonitors() {
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
            globalClickMonitor = nil
        }
        if let obs = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            appActivationObserver = nil
        }
    }
}

final class PopupViewModel: ObservableObject {
    @Published var source: String = ""
    @Published var translation: String?
    @Published var originalText: String = ""
    @Published var isLoading: Bool = false
}

struct PopupView: View {
    @ObservedObject var viewModel: PopupViewModel
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.source)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)

                    Divider()

                    if viewModel.isLoading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("翻译中…").foregroundColor(.secondary).font(.system(size: 12))
                        }
                    } else if let t = viewModel.translation {
                        Text(t)
                            .font(.system(size: 14, weight: .medium))
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                // 给右上角浮动按钮留点空间
                .padding(.trailing, 20)
            }

            // 右上角浮动的复制按钮，仅在有译文时出现
            if let _ = viewModel.translation, !viewModel.isLoading {
                Button(action: copyTranslation) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(
                            Circle().fill(Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help("复制译文")
                .padding(10)
            }
        }
        .frame(width: 380, height: 220)
        // Esc 关闭
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }

    private func copyTranslation() {
        guard let t = viewModel.translation else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(t, forType: .string)
    }
}
