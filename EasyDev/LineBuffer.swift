//
//  LineBuffer.swift
//  EasyDev
//

import Foundation

/// 把子进程管道数据切成行，兼容 \n 与 \r（git 进度条）。
final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = ""
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        lock.lock()
        pending += text
        var lines: [String] = []
        var current = ""
        for char in pending {
            if char == "\n" || char == "\r" {
                if !current.isEmpty {
                    lines.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        pending = current
        lock.unlock()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { onLine(trimmed) }
        }
    }

    func flush() {
        lock.lock()
        let rest = pending
        pending = ""
        lock.unlock()

        let trimmed = rest.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { onLine(trimmed) }
    }
}
