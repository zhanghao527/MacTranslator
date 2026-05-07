import AppKit
import SwiftUI

final class TranslationPopupWindow {
    private var window: NSPanel?
    private let viewModel = PopupViewModel()

    func show(source: String, translation: String?, originalText: String) {
        viewModel.source = source
        viewModel.translation = translation
        viewModel.originalText = originalText
        viewModel.isLoading = translation == nil

        if window == nil {
            let hosting = NSHostingController(rootView: PopupView(viewModel: viewModel))
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.contentViewController = hosting
            panel.backgroundColor = NSColor.windowBackgroundColor
            panel.hasShadow = true
            self.window = panel
        }

        positionWindowNearMouse()
        window?.orderFrontRegardless()
    }

    private func positionWindowNearMouse() {
        guard let window = window else { return }
        let mouse = NSEvent.mouseLocation
        // 放在鼠标右下方一点点
        let size = window.frame.size
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - size.height - 12)

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
            let vf = screen.visibleFrame
            origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
            origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        }
        window.setFrameOrigin(origin)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mac Translator")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: copyTranslation) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("复制译文")
                .disabled(viewModel.translation == nil || viewModel.isLoading)
            }

            Divider()

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
            }
        }
        .padding(14)
        .frame(width: 380, height: 220)
    }

    private func copyTranslation() {
        guard let t = viewModel.translation else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(t, forType: .string)
    }
}
