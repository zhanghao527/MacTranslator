import Foundation
import SwiftUI
import Translation

/// 系统翻译错误
enum SystemTranslatorError: LocalizedError {
    case unavailable
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .unavailable: return "系统翻译不可用（需要 macOS 15+）"
        case .emptyResult: return "系统翻译结果为空"
        }
    }
}

@available(macOS 15.0, *)
extension TranslationSession: @unchecked @retroactive Sendable {}

/// 用 actor 安全管理 continuation 与 session，处理二者到达顺序不确定的竞态
@available(macOS 15.0, *)
private actor SessionManager {
    private var continuation: CheckedContinuation<TranslationSession, Never>?
    private var pendingSession: TranslationSession?

    func storeContinuation(_ c: CheckedContinuation<TranslationSession, Never>) {
        // session 已先到（translationTask 比 store 更早触发）时立刻兑现
        if let s = pendingSession {
            pendingSession = nil
            c.resume(returning: s)
        } else {
            continuation = c
        }
    }

    func resume(with session: TranslationSession) {
        // continuation 还没存进来时先暂存 session，避免丢失导致永久挂起
        if let c = continuation {
            continuation = nil
            c.resume(returning: session)
        } else {
            pendingSession = session
        }
    }
}

/// 宿主视图：创建时就带上 configuration，translationTask 触发后把 session 交回去
@available(macOS 15.0, *)
private struct SessionProviderView: View {
    let configuration: TranslationSession.Configuration
    let manager: SessionManager

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(configuration) { session in
                await manager.resume(with: session)
            }
    }
}

@available(macOS 15.0, *)
@MainActor
final class SystemTranslator {
    static let shared = SystemTranslator()
    private var hostWindow: NSWindow?
    private init() {}

    /// 屏幕外的极小宿主窗口，用于承载驱动 translationTask 的 SwiftUI 视图
    private func ensureHostWindow() -> NSWindow {
        if let w = hostWindow { return w }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.alphaValue = 0.001
        win.ignoresMouseEvents = true
        win.level = .init(rawValue: -10000)
        win.collectionBehavior = [.stationary, .ignoresCycle, .canJoinAllSpaces]
        win.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        win.orderFrontRegardless()
        hostWindow = win
        return win
    }
}

@available(macOS 15.0, *)
extension SystemTranslator {
    /// 翻译入口：把宿主视图挂进真实窗口层级来驱动 translationTask
    func translate(text: String, source: Locale.Language?, target: Locale.Language) async throws -> String {
        let config = makeConfiguration(source: source, target: target)
        let manager = SessionManager()
        let window = ensureHostWindow()

        let hosting = NSHostingView(
            rootView: SessionProviderView(configuration: config, manager: manager)
        )
        hosting.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        window.contentView?.addSubview(hosting)
        defer { hosting.removeFromSuperview() }

        let session: TranslationSession = await withCheckedContinuation { cont in
            Task { await manager.storeContinuation(cont) }
        }

        try await session.prepareTranslation()
        let response = try await session.translate(text)
        let result = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty { throw SystemTranslatorError.emptyResult }
        return result
    }
}

@available(macOS 15.0, *)
extension SystemTranslator {
    /// macOS 26.4 起默认走 high-fidelity（AI/LLM）策略，依赖 Apple Intelligence；
    /// 不支持 AI 的机器会一直挂起。强制 lowLatency（传统引擎）走本地语言包，秒回。
    private func makeConfiguration(
        source: Locale.Language?, target: Locale.Language
    ) -> TranslationSession.Configuration {
        if #available(macOS 26.4, *) {
            return TranslationSession.Configuration(
                source: source, target: target, preferredStrategy: .lowLatency
            )
        } else {
            return TranslationSession.Configuration(source: source, target: target)
        }
    }
}
