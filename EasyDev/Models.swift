//
//  Models.swift
//  EasyDev
//

import Foundation

// MARK: - Tweak 项目

struct TweakProject: Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: URL
    var language: TweakLanguage
    var scheme: PackageScheme
    var environmentID: TheosEnvironment.ID?
    var lastBuilt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        language: TweakLanguage = .logos,
        scheme: PackageScheme = .rootless,
        environmentID: TheosEnvironment.ID? = nil,
        lastBuilt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.language = language
        self.scheme = scheme
        self.environmentID = environmentID
        self.lastBuilt = lastBuilt
    }
}

enum TweakLanguage: String, CaseIterable, Identifiable {
    case logos = "Logos"
    case objectiveC = "Objective-C"
    case objectiveCpp = "Objective-C++"
    case swift = "Swift"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .logos: return "text.badge.plus"
        case .objectiveC: return "c.circle"
        case .objectiveCpp: return "plus.circle"
        case .swift: return "swift"
        }
    }

    var fileExtension: String {
        switch self {
        case .logos: return "xmi"
        case .objectiveC: return "m"
        case .objectiveCpp: return "mm"
        case .swift: return "swift"
        }
    }
}

enum PackageScheme: String, CaseIterable, Identifiable {
    case rootful = "rootful"
    case rootless = "rootless"
    case rootHide = "roothide"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rootful: return "Rootful"
        case .rootless: return "Rootless"
        case .rootHide: return "RootHide"
        }
    }

    var installPath: String {
        switch self {
        case .rootful: return "/Library/MobileSubstrate/DynamicLibraries"
        case .rootless, .rootHide: return "/var/jb/Library/MobileSubstrate/DynamicLibraries"
        }
    }
}

// MARK: - Theos 环境

struct TheosEnvironment: Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: URL
    var kind: EnvironmentKind
    var isAvailable: Bool
    var sdkVersions: [String]

    init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        kind: EnvironmentKind,
        isAvailable: Bool = true,
        sdkVersions: [String] = []
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.kind = kind
        self.isAvailable = isAvailable
        self.sdkVersions = sdkVersions
    }

    var latestSDK: String? {
        sdkVersions.max { lhs, rhs in
            lhs.compare(rhs, options: .numeric) == .orderedAscending
        }
    }
}

enum EnvironmentKind: String, CaseIterable {
    case standard = "标准 Theos"
    case rootHide = "RootHide Theos"

    var icon: String {
        switch self {
        case .standard: return "shippingbox"
        case .rootHide: return "eye.slash"
        }
    }
}

// MARK: - 依赖

struct DependencyInfo: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var detail: String
    var required: Bool
    var installed: Bool
    var version: String?
    var path: String?
}

// MARK: - 构建

enum BuildStatus: Equatable {
    case idle
    case building
    case succeeded(Date)
    case failed(Date)

    var label: String {
        switch self {
        case .idle: return "就绪"
        case .building: return "构建中…"
        case .succeeded: return "构建成功"
        case .failed: return "构建失败"
        }
    }

    var isBusy: Bool {
        if case .building = self { return true }
        return false
    }
}

struct LogLine: Identifiable, Equatable {
    enum Level {
        case info, success, warning, error, command

        var colorName: String {
            switch self {
            case .info: return "secondary"
            case .success: return "green"
            case .warning: return "orange"
            case .error: return "red"
            case .command: return "accentColor"
            }
        }

        var symbol: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.octagon"
            case .command: return "chevron.right"
            }
        }
    }

    let id = UUID()
    var level: Level
    var text: String
    var timestamp: Date = .init()
}

// MARK: - 设备

struct TweakDevice: Identifiable, Hashable {
    let id: UUID
    var name: String
    var model: String
    var osVersion: String
    var connection: Connection

    init(
        id: UUID = UUID(),
        name: String,
        model: String,
        osVersion: String,
        connection: Connection = .usb
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.osVersion = osVersion
        self.connection = connection
    }

    enum Connection: String {
        case usb = "USB"
        case wifi = "Wi-Fi"
    }
}
