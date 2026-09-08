import Foundation

enum TranslatorError: LocalizedError {
    case unavailable
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .unavailable: return "系统翻译不可用（需要 macOS 15+）"
        case .emptyResult: return "翻译结果为空"
        }
    }
}

final class Translator {
    static let shared = Translator()
    private init() {}

    /// 只用 macOS 系统翻译（本地）。自动判向：中文 → 英文，其他 → 中文
    func translate(text: String) async throws -> String {
        guard #available(macOS 15.0, *) else {
            throw TranslatorError.unavailable
        }
        let (sl, tl) = detectDirection(text)
        let sourceLang = Locale.Language(identifier: sl == "zh-CN" ? "zh-Hans" : "en")
        let targetLang = Locale.Language(identifier: tl == "en" ? "en" : "zh-Hans")
        return try await withTimeout(seconds: 8) {
            try await SystemTranslator.shared.translate(
                text: text, source: sourceLang, target: targetLang
            )
        }
    }

    private func detectDirection(_ text: String) -> (String, String) {
        for scalar in text.unicodeScalars {
            if (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) {
                return ("zh-CN", "en")
            }
        }
        return ("en", "zh-CN")
    }
}
