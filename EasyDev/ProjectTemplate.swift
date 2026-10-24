//
//  ProjectTemplate.swift
//  EasyDev
//

import Foundation

/// 对应 Theos `nic.pl` 内置模板。
enum ProjectTemplate: String, CaseIterable, Identifiable {
    case tweak = "iphone/tweak"
    case tweakWithPrefs = "iphone/tweak_with_simple_preferences"
    case tweakSwift = "iphone/tweak_swift"
    case tool = "iphone/tool"
    case toolSwift = "iphone/tool_swift"
    case library = "iphone/library"
    case framework = "iphone/framework"
    case preferenceBundle = "iphone/preference_bundle"
    case preferenceBundleSwift = "iphone/preference_bundle_swift"
    case application = "iphone/application_modern"
    case applicationSwift = "iphone/application_swift_modern"
    case applicationSwiftUI = "iphone/application_swiftui"
    case theme = "iphone/theme"
    case xpcService = "iphone/xpc_service_modern"
    case controlCenter = "iphone/control_center_module-11up"
    case empty = "iphone/null"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tweak: return "Tweak"
        case .tweakWithPrefs: return "Tweak + 设置面板"
        case .tweakSwift: return "Tweak（Swift）"
        case .tool: return "命令行工具"
        case .toolSwift: return "命令行工具（Swift）"
        case .library: return "动态库"
        case .framework: return "Framework"
        case .preferenceBundle: return "设置面板"
        case .preferenceBundleSwift: return "设置面板（Swift）"
        case .application: return "应用"
        case .applicationSwift: return "应用（Swift）"
        case .applicationSwiftUI: return "应用（SwiftUI）"
        case .theme: return "主题"
        case .xpcService: return "XPC 服务"
        case .controlCenter: return "控制中心模块"
        case .empty: return "空项目"
        }
    }

    var group: String {
        switch self {
        case .tweak, .tweakWithPrefs, .tweakSwift: return "Tweak"
        case .tool, .toolSwift: return "工具"
        case .library, .framework: return "库与框架"
        case .preferenceBundle, .preferenceBundleSwift: return "设置面板"
        case .application, .applicationSwift, .applicationSwiftUI: return "应用"
        case .theme, .xpcService, .controlCenter, .empty: return "其他"
        }
    }

    /// 是否需要在向导里选择源码语言。
    var supportsLanguageSelection: Bool {
        switch self {
        case .tweak, .tweakWithPrefs: return true
        default: return false
        }
    }

    /// 是否是 Logos tweak（用于替换示例源码）。
    var isLogosTweak: Bool {
        self == .tweak || self == .tweakWithPrefs
    }

    static var grouped: [(group: String, templates: [ProjectTemplate])] {
        let order = ["Tweak", "工具", "库与框架", "设置面板", "应用", "其他"]
        let grouped = Dictionary(grouping: allCases, by: \.group)
        return order.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key, items)
        }
    }
}
