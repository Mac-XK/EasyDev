//
//  SystemDetector.swift
//  EasyDev
//

import Foundation

enum SystemDetector {

    // MARK: - Theos 环境

    /// 扫描常见路径，返回检测到的 Theos 环境。
    static func detectEnvironments() -> [TheosEnvironment] {
        var candidates: [(path: String, hint: EnvironmentKind)] = [
            ("/opt/theos", .standard),
            ("/opt/roothide-theos", .rootHide),
            ("/opt/theos-roothide", .rootHide),
            (NSHomeDirectory() + "/theos", .standard),
            (NSHomeDirectory() + "/Library/Application Support/EasyDev/theos", .standard),
            (NSHomeDirectory() + "/Library/Application Support/EasyDev/roothide-theos", .rootHide),
        ]

        // 环境变量优先
        if let env = ProcessInfo.processInfo.environment["THEOS"], !env.isEmpty {
            let hint: EnvironmentKind = env.lowercased().contains("roothide") ? .rootHide : .standard
            candidates.insert((env, hint), at: 0)
        }

        var results: [TheosEnvironment] = []
        var seen = Set<String>()

        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate.path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let canonical = url.resolvingSymlinksInPath().path
            guard !seen.contains(canonical) else { continue }
            seen.insert(canonical)

            // 路径里带 roothide 的一律按 RootHide 归类
            let kind: EnvironmentKind =
                candidate.hint == .rootHide || canonical.lowercased().contains("roothide")
                ? .rootHide : .standard

            let valid = isValidTheos(url)
            let sdks = valid ? scanSDKs(url) : []

            results.append(
                TheosEnvironment(
                    name: kind == .rootHide ? "RootHide Theos" : "标准 Theos",
                    path: url,
                    kind: kind,
                    isAvailable: valid,
                    sdkVersions: sdks
                )
            )
        }
        return results
    }

    /// 判断目录是否是有效的 Theos 安装。
    static func isValidTheos(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.appendingPathComponent("makefiles").path)
            && fm.fileExists(atPath: url.appendingPathComponent("bin/nic.pl").path)
    }

    /// 读取 sdks/ 下的 iPhoneOS*.sdk，返回按版本排序的版本号数组。
    static func scanSDKs(_ url: URL) -> [String] {
        let sdksDir = url.appendingPathComponent("sdks")
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: sdksDir.path) else {
            return []
        }

        var versions: [String] = []
        for item in items {
            guard item.hasPrefix("iPhoneOS"), item.hasSuffix(".sdk") else { continue }
            let version = item
                .dropFirst("iPhoneOS".count)
                .dropLast(".sdk".count)
            if !version.isEmpty {
                versions.append(String(version))
            }
        }

        return versions.sorted {
            $0.compare($1, options: .numeric) == .orderedAscending
        }
    }

    // MARK: - 依赖

    static func detectDependencies() -> [DependencyInfo] {
        let specs: [(name: String, detail: String, required: Bool, args: [String])] = [
            ("git",   "克隆 Theos 与子模块",  true,  ["--version"]),
            ("make",  "驱动 Theos 构建",     true,  ["--version"]),
            ("ldid",  "重签名 dylib",        true,  []),
            ("dpkg",  "打包 .deb",           true,  ["--version"]),
            ("perl",  "Logos 预处理器依赖",   true,  ["-v"]),
            ("brew",  "安装缺失依赖",         false, ["--version"]),
        ]

        return specs.map { spec in
            let path = which(spec.name)
            let version = path.flatMap { firstLine(of: $0, arguments: spec.args) }
            return DependencyInfo(
                name: spec.name,
                detail: spec.detail,
                required: spec.required,
                installed: path != nil,
                version: version.map { normalize($0) },
                path: path
            )
        }
    }

    /// PATH 查找可执行文件。
    static func which(_ name: String) -> String? {
        let envPath = ProcessInfo.processInfo.environment["PATH"]
            ?? "/usr/bin:/bin:/usr/sbin:/sbin"

        for dir in envPath.split(separator: ":") {
            let candidate = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        for candidate in ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func firstLine(of path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return text
                .split(separator: "\n")
                .first
                .map { $0.trimmingCharacters(in: .whitespaces) }
        } catch {
            return nil
        }
    }

    /// 从版本输出里提取一个短版本号，例如 "git version 2.50.1" -> "2.50.1"
    private static func normalize(_ text: String) -> String {
        let pattern = #"\d+(\.\d+)+"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return text
    }
}
