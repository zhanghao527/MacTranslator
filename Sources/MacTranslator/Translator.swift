import Foundation

enum TranslatorError: LocalizedError {
    case badResponse
    case emptyResult
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "服务器返回格式异常"
        case .emptyResult: return "翻译结果为空"
        case .http(let code): return "HTTP \(code)"
        }
    }
}

final class Translator {
    static let shared = Translator()
    private init() {}

    /// 自动判向：中文 → 英文，其他 → 中文
    func translate(text: String) async throws -> String {
        let (sl, tl) = detectDirection(text)
        return try await googleTranslate(text: text, sourceLang: sl, targetLang: tl)
    }

    private func detectDirection(_ text: String) -> (String, String) {
        for scalar in text.unicodeScalars {
            // CJK 基本区
            if (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) {
                return ("zh-CN", "en")
            }
        }
        return ("auto", "zh-CN")
    }

    private func googleTranslate(text: String, sourceLang: String, targetLang: String) async throws -> String {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sourceLang),
            URLQueryItem(name: "tl", value: targetLang),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        guard let url = components.url else { throw TranslatorError.badResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw TranslatorError.http(http.statusCode)
        }

        // Google 返回的是嵌套数组：[[[译文, 原文, null, null, ...], ...], ...]
        guard let json = try JSONSerialization.jsonObject(with: data) as? [Any],
              let segments = json.first as? [Any] else {
            throw TranslatorError.badResponse
        }

        var result = ""
        for seg in segments {
            if let arr = seg as? [Any], let piece = arr.first as? String {
                result += piece
            }
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw TranslatorError.emptyResult }
        return trimmed
    }
}
