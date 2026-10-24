//
//  TheosInstaller.swift
//  EasyDev
//

import Foundation

enum TheosInstaller {

    static func repository(for kind: EnvironmentKind) -> String {
        switch kind {
        case .standard:
            return "https://github.com/theos/theos.git"
        case .rootHide:
            return "https://github.com/roothide/theos.git"
        }
    }

    static func defaultPath(for kind: EnvironmentKind) -> URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/EasyDev", isDirectory: true)
        let name = kind == .rootHide ? "roothide-theos" : "theos"
        return base.appendingPathComponent(name, isDirectory: true)
    }

    /// 克隆 Theos 仓库并初始化子模块。
    static func install(
        kind: EnvironmentKind,
        to destination: URL,
        proxy: String?,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws {
        let fm = FileManager.default
        try fm.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fm.fileExists(atPath: destination.path),
           let items = try? fm.contentsOfDirectory(atPath: destination.path),
           !items.isEmpty {
            throw TheosInstallError.destinationNotEmpty(destination.path)
        }

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        if let proxy, !proxy.isEmpty {
            environment["https_proxy"] = proxy
            environment["http_proxy"] = proxy
            environment["all_proxy"] = proxy
        }

        onLine("$ git clone --recursive \(repository(for: kind))")
        try await run(
            "/usr/bin/git",
            ["clone", "--recursive", "--progress", repository(for: kind), destination.path],
            environment: environment,
            onLine: onLine
        )

        onLine("$ git submodule update --init --recursive")
        try await run(
            "/usr/bin/git",
            ["-C", destination.path, "submodule", "update", "--init", "--recursive"],
            environment: environment,
            onLine: onLine
        )
    }

    // MARK: - 进程

    private static func run(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String],
        onLine: @escaping @Sendable (String) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = environment

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let buffer = LineBuffer(onLine: onLine)

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                buffer.append(data)
            }

            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                buffer.flush()
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TheosInstallError.failed(proc.terminationStatus))
                }
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

enum TheosInstallError: LocalizedError {
    case failed(Int32)
    case destinationNotEmpty(String)

    var errorDescription: String? {
        switch self {
        case .failed(let code):
            return "安装命令失败（退出码 \(code)）"
        case .destinationNotEmpty(let path):
            return "目标目录非空：\(path)"
        }
    }
}
