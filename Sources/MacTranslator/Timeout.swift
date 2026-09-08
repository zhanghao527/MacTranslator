import Foundation

struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        "系统翻译超时：离线翻译组件可能未就绪。请到「系统设置 → 翻译语言」下载中文与英语的离线包后重试。"
    }
}

func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
