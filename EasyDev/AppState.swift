//
//  AppState.swift
//  EasyDev
//

import Foundation
import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // MARK: 项目

    @Published var projects: [TweakProject] = []
    @Published var selectedProjectID: TweakProject.ID?

    var selectedProject: TweakProject? {
        guard let id = selectedProjectID else { return nil }
        return projects.first { $0.id == id }
    }

    // MARK: 环境

    @Published var environments: [TheosEnvironment] = []
    @Published var selectedEnvironmentID: TheosEnvironment.ID?

    var activeEnvironment: TheosEnvironment? {
        if let id = selectedEnvironmentID,
           let env = environments.first(where: { $0.id == id }) {
            return env
        }
        return environments.first { $0.isAvailable }
    }

    // MARK: SDK 选择

    /// 每个环境选中的 SDK，key 为环境路径。
    @Published var selectedSDKs: [String: String] = [:]

    /// 正在安装的环境类型。
    @Published var installingKind: EnvironmentKind?

    /// 用户配置的代理地址（可空）。
    var proxyAddress: String {
        UserDefaults.standard.string(forKey: "EasyDevProxy") ?? ""
    }

    func sdkVersion(for environment: TheosEnvironment) -> String? {
        if let version = selectedSDKs[environment.path.path],
           environment.sdkVersions.contains(version) {
            return version
        }
        return environment.latestSDK
    }

    func selectSDK(_ version: String, for environment: TheosEnvironment) {
        selectedSDKs[environment.path.path] = version
        UserDefaults.standard.set(selectedSDKs, forKey: "EasyDevSelectedSDKs")
        append(.info, "\(environment.name) 选用 SDK \(version)")
    }

    // MARK: 依赖

    @Published var dependencies: [DependencyInfo] = []

    var missingRequiredDependencies: [DependencyInfo] {
        dependencies.filter { $0.required && !$0.installed }
    }

    // MARK: 设备

    @Published var devices: [TweakDevice] = []
    @Published var selectedDeviceID: TweakDevice.ID?

    var selectedDevice: TweakDevice? {
        guard let id = selectedDeviceID else { return nil }
        return devices.first { $0.id == id }
    }

    // MARK: 构建

    @Published var buildStatus: BuildStatus = .idle
    @Published var logs: [LogLine] = []
    @Published var isLogVisible = true

    // MARK: 界面

    enum SidebarItem: Hashable {
        case home
        case project(TweakProject.ID)
        case environments
        case dependencies
    }

    @Published var sidebarSelection: SidebarItem? = .home
    @Published var isShowingNewProject = false

    // MARK: 初始化

    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: "EasyDevSelectedSDKs") as? [String: String] {
            selectedSDKs = saved
        }
        refresh()
    }

    // MARK: 安装环境

    func installEnvironment(_ kind: EnvironmentKind) {
        guard installingKind == nil else { return }

        let destination = TheosInstaller.defaultPath(for: kind)
        installingKind = kind
        isLogVisible = true

        append(.command, "安装 \(kind.rawValue) → \(destination.path)")

        let proxy = proxyAddress.isEmpty ? nil : proxyAddress

        Task {
            do {
                try await TheosInstaller.install(
                    kind: kind,
                    to: destination,
                    proxy: proxy
                ) { line in
                    Task { @MainActor [weak self] in
                        self?.append(.info, line)
                    }
                }
                await MainActor.run {
                    self.installingKind = nil
                    self.append(.success, "\(kind.rawValue) 安装完成")
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.installingKind = nil
                    self.append(.error, "安装失败：\(error.localizedDescription)")
                }
            }
        }
    }

    /// 重新扫描系统环境与依赖。
    func refresh() {
        let detected = SystemDetector.detectEnvironments()
        environments = detected

        if selectedEnvironmentID == nil || !detected.contains(where: { $0.id == selectedEnvironmentID }) {
            selectedEnvironmentID = detected.first(where: { $0.isAvailable })?.id
        }

        dependencies = SystemDetector.detectDependencies()

        rebuildStartupLog()
    }

    private func rebuildStartupLog() {
        logs.removeAll()
        logs.append(LogLine(level: .info, text: "EasyDev 已就绪"))

        if let env = activeEnvironment {
            logs.append(LogLine(level: .success, text: "检测到 \(env.name): \(env.path.path)"))
            if let sdk = env.latestSDK {
                logs.append(LogLine(level: .info, text: "SDK \(sdk)（共 \(env.sdkVersions.count) 个版本）"))
            } else {
                logs.append(LogLine(level: .warning, text: "尚未安装 iOS SDK"))
            }
        } else {
            logs.append(LogLine(level: .warning, text: "未检测到 Theos 环境"))
        }

        let missing = missingRequiredDependencies
        if missing.isEmpty {
            logs.append(LogLine(level: .success, text: "依赖完整"))
        } else {
            logs.append(LogLine(level: .error, text: "缺少依赖: \(missing.map(\.name).joined(separator: ", "))"))
        }
    }

    // MARK: 项目

    func selectProject(_ project: TweakProject) {
        selectedProjectID = project.id
        sidebarSelection = .project(project.id)
    }

    // MARK: 构建

    private var buildProcess: Process?

    func build() {
        guard let project = selectedProject, !buildStatus.isBusy else { return }

        guard let env = activeEnvironment else {
            buildStatus = .failed(Date())
            isLogVisible = true
            append(.error, "未配置 Theos 环境，请先在「Theos 环境」中安装或选择")
            return
        }

        // 检查当前 Theos 是否支持所选打包方案
        if project.scheme != .rootful {
            let modPath = env.path
                .appendingPathComponent("vendor/mod", isDirectory: true)
                .appendingPathComponent(project.scheme.rawValue, isDirectory: true)
            if !FileManager.default.fileExists(atPath: modPath.path) {
                buildStatus = .failed(Date())
                isLogVisible = true
                append(.error, "\(env.name) 不支持 \(project.scheme.displayName) 打包")
                append(.info, "标准 Theos 仅支持 Rootful / Rootless；RootHide 需要 /opt/theos-roothide")
                return
            }
        }

        let makefile = project.path.appendingPathComponent("Makefile")
        guard FileManager.default.fileExists(atPath: makefile.path) else {
            buildStatus = .failed(Date())
            isLogVisible = true
            append(.error, "未找到 Makefile：\(project.path.path)")
            return
        }

        buildStatus = .building
        isLogVisible = true
        logs.removeAll()

        let sdk = sdkVersion(for: env)
        var envVars = ProcessInfo.processInfo.environment

        // GUI 应用的 PATH 通常不含 Homebrew，补上以便找到 ldid / dpkg / make
        let basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        let existingPath = envVars["PATH"] ?? ""
        envVars["PATH"] = existingPath.isEmpty ? basePath : "\(basePath):\(existingPath)"

        envVars["THEOS"] = env.path.path
        envVars["THEOS_PACKAGE_SCHEME"] = project.scheme.rawValue
        envVars["ARCHS"] = "arm64 arm64e"
        if let sdk {
            envVars["TARGET"] = "iphone:clang:\(sdk):15.0"
        }

        append(.command, "make package")
        append(.info, "项目: \(project.name)  (\(project.path.path))")
        append(.info, "环境: \(env.name)  \(env.path.path)")
        append(.info, "方案: \(project.scheme.displayName) · SDK: \(sdk ?? "默认")")

        var arguments = ["package"]
        arguments.append("THEOS=\(env.path.path)")
        arguments.append("ARCHS=arm64 arm64e")
        if let sdk {
            arguments.append("TARGET=iphone:clang:\(sdk):15.0")
        }
        if project.scheme != .rootful {
            arguments.append("THEOS_PACKAGE_SCHEME=\(project.scheme.rawValue)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/make")
        process.arguments = arguments
        process.currentDirectoryURL = project.path
        process.environment = envVars

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let buffer = LineBuffer { [weak self] line in
            Task { @MainActor in
                self?.appendParsed(line)
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                buffer.append(data)
            }
        }

        process.terminationHandler = { [weak self] proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            buffer.flush()
            Task { @MainActor in
                guard let self else { return }
                self.buildProcess = nil
                if proc.terminationStatus == 0 {
                    self.append(.success, "构建完成")
                    if let path = self.selectedProject?.path {
                        let artifacts = self.findArtifacts(in: path)
                        self.lastArtifacts = artifacts
                        for artifact in artifacts {
                            self.append(.success, "产物：\(artifact.lastPathComponent)")
                        }
                    }
                    self.buildStatus = .succeeded(Date())
                } else {
                    self.append(.error, "构建失败（退出码 \(proc.terminationStatus)）")
                    self.buildStatus = .failed(Date())
                }
            }
        }

        do {
            try process.run()
            buildProcess = process
        } catch {
            append(.error, "无法启动 make：\(error.localizedDescription)")
            buildStatus = .failed(Date())
        }
    }

    func cancelBuild() {
        guard let process = buildProcess, process.isRunning else { return }
        append(.warning, "正在终止构建…")
        process.terminate()
    }

    @Published var lastArtifacts: [URL] = []

    private func findArtifacts(in projectPath: URL) -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []

        let packages = projectPath.appendingPathComponent("packages", isDirectory: true)
        if let items = try? fm.contentsOfDirectory(at: packages, includingPropertiesForKeys: nil) {
            result += items
                .filter { $0.pathExtension == "deb" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        }

        let obj = projectPath.appendingPathComponent(".theos/obj/debug", isDirectory: true)
        if let items = try? fm.contentsOfDirectory(at: obj, includingPropertiesForKeys: nil) {
            result += items
                .filter { $0.pathExtension == "dylib" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        return result
    }

    /// 在 Finder 中定位构建产物。
    func revealArtifacts() {
        guard let project = selectedProject else { return }

        if !lastArtifacts.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(lastArtifacts)
            return
        }

        let packages = project.path.appendingPathComponent("packages", isDirectory: true)
        if FileManager.default.fileExists(atPath: packages.path) {
            NSWorkspace.shared.activateFileViewerSelecting([packages])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([project.path])
        }
    }

    private func stripANSI(_ text: String) -> String {
        var result = text
        // 完整 ANSI 序列
        result = result.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*[a-zA-Z]",
            with: "",
            options: .regularExpression
        )
        // 残留的 [0;34m 之类
        result = result.replacingOccurrences(
            of: "\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func appendParsed(_ raw: String) {
        let line = stripANSI(raw)
        guard !line.isEmpty else { return }
        let lower = line.lowercased()
        let level: LogLine.Level

        if lower.contains("error:") {
            level = .error
        } else if lower.contains("warning:") {
            level = .warning
        } else if line.hasPrefix("==>") {
            level = .command
        } else if lower.contains("done") || lower.contains("succeeded") || lower.contains("making all") {
            level = .success
        } else {
            level = .info
        }

        append(level, line)
    }

    // MARK: 打开项目

    func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "打开"
        panel.message = "选择包含 Makefile 的 Tweak 项目目录"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addProject(at: url)
    }

    func addProject(at url: URL) {
        if let existing = projects.first(where: {
            $0.path.standardizedFileURL == url.standardizedFileURL
        }) {
            selectProject(existing)
            return
        }

        let files = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        let language: TweakLanguage
        if files.contains(where: { $0.hasSuffix(".xmi") || $0.hasSuffix(".xm") }) {
            language = .logos
        } else if files.contains(where: { $0.hasSuffix(".swift") }) {
            language = .swift
        } else if files.contains(where: { $0.hasSuffix(".mm") }) {
            language = .objectiveCpp
        } else {
            language = .objectiveC
        }

        let project = TweakProject(
            name: url.lastPathComponent,
            path: url,
            language: language,
            scheme: .rootless,
            environmentID: activeEnvironment?.id
        )

        projects.append(project)
        selectProject(project)
        append(.success, "已添加项目 \(project.name)")
    }

    // MARK: 工具

    func append(_ level: LogLine.Level, _ text: String) {
        logs.append(LogLine(level: level, text: text))
    }

    func clearLogs() {
        logs.removeAll()
    }
}
