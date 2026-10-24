//
//  ProjectCreator.swift
//  EasyDev
//

import Foundation

enum ProjectCreator {

    struct Options {
        var name: String
        var parentDirectory: URL
        var template: ProjectTemplate
        var scheme: PackageScheme
        var sdkVersion: String?
        var bundlePrefix: String
        var theosPath: URL
    }

    enum CreateError: LocalizedError {
        case invalidName
        case alreadyExists(String)
        case theosNotFound(String)
        case nicFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidName:
                return "项目名不能为空，且不能包含 / : 等字符"
            case .alreadyExists(let path):
                return "目录已存在：\(path)"
            case .theosNotFound(let path):
                return "找不到 Theos：\(path)"
            case .nicFailed(let message):
                return "nic.pl 执行失败：\(message)"
            }
        }
    }

    static func defaultParentDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("EasyDevProjects", isDirectory: true)
    }

    /// 调用 Theos 的 nic.pl 生成项目，再做必要后处理。
    static func create(_ options: Options) throws -> URL {
        let name = options.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !name.contains("/"),
              !name.contains(":"),
              name.rangeOfCharacter(from: .alphanumerics) != nil else {
            throw CreateError.invalidName
        }

        let nic = options.theosPath.appendingPathComponent("bin/nic.pl")
        guard FileManager.default.fileExists(atPath: nic.path) else {
            throw CreateError.theosNotFound(options.theosPath.path)
        }

        let fm = FileManager.default
        try fm.createDirectory(at: options.parentDirectory, withIntermediateDirectories: true)

        let projectURL = options.parentDirectory.appendingPathComponent(name, isDirectory: true)
        if fm.fileExists(atPath: projectURL.path) {
            throw CreateError.alreadyExists(projectURL.path)
        }

        let identifier = name.replacingOccurrences(of: " ", with: "")
        let bundle = "\(options.bundlePrefix).\(identifier.lowercased())"

        try runNIC(
            nic: nic,
            template: options.template,
            name: name,
            bundle: bundle,
            theosPath: options.theosPath,
            workingDirectory: options.parentDirectory
        )

        guard fm.fileExists(atPath: projectURL.path) else {
            throw CreateError.nicFailed("模板未生成目录")
        }

        try postProcess(
            projectURL: projectURL,
            identifier: identifier,
            options: options
        )

        return projectURL
    }

    // MARK: - nic.pl

    private static func runNIC(
        nic: URL,
        template: ProjectTemplate,
        name: String,
        bundle: String,
        theosPath: URL,
        workingDirectory: URL
    ) throws {
        let process = Process()
        process.executableURL = nic
        process.arguments = [
            "-t", template.rawValue,
            "-n", name,
            "-p", bundle,
            "-u", NSUserName()
        ]
        process.currentDirectoryURL = workingDirectory
        process.standardInput = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        environment["THEOS"] = theosPath.path
        let basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        let existing = environment["PATH"] ?? ""
        environment["PATH"] = existing.isEmpty ? basePath : "\(basePath):\(existing)"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw CreateError.nicFailed(text.isEmpty ? "退出码 \(process.terminationStatus)" : text)
        }
    }

    // MARK: - 后处理

    private static func postProcess(
        projectURL: URL,
        identifier: String,
        options: Options
    ) throws {
        let fm = FileManager.default
        let makefileURL = projectURL.appendingPathComponent("Makefile")

        guard var makefile = try? String(contentsOf: makefileURL, encoding: .utf8) else {
            return
        }

        // 1. 替换 SDK / 部署版本
        let sdk = options.sdkVersion ?? "16.5"
        makefile = makefile.replacingOccurrences(
            of: #"TARGET\s*:?=\s*iphone:clang:[^\n]*"#,
            with: "TARGET := iphone:clang:\(sdk):15.0",
            options: .regularExpression
        )

        // 2. Logos tweak：把示例源码换成可用的 hook 骨架
        if options.template.isLogosTweak {
            let sourceURL = projectURL.appendingPathComponent("Tweak.x")
            try logosSource(name: identifier)
                .write(to: sourceURL, atomically: true, encoding: .utf8)
        }

        // 3. 确保有 MobileSubstrate 过滤器
        let filterURL = projectURL.appendingPathComponent("\(identifier).plist")
        if !fm.fileExists(atPath: filterURL.path) {
            try filterPlist().write(to: filterURL, atomically: true, encoding: .utf8)
        }

        try makefile.write(to: makefileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - 模板

    private static func logosSource(name: String) -> String {
        """
        #import <Foundation/Foundation.h>
        #import <UIKit/UIKit.h>

        %hook UIApplication

        - (BOOL)application:(UIApplication *)application
                didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
            BOOL result = %orig;
            NSLog(@"[\(name)] loaded into %@", [[NSBundle mainBundle] bundleIdentifier]);
            return result;
        }

        %end

        %ctor {
            %init;
        }

        """
    }

    private static func objcSource(name: String, cpp: Bool) -> String {
        let cppInclude = cpp ? "#include <string>\n\n" : ""
        return """
        #import <Foundation/Foundation.h>
        #import <UIKit/UIKit.h>
        #import <objc/runtime.h>
        #import <substrate.h>

        \(cppInclude)static BOOL (*orig$applicationDidFinishLaunching)(id, SEL, id, id);

        static BOOL hook$applicationDidFinishLaunching(id self, SEL _cmd, id application, id launchOptions) {
            NSLog(@"[\(name)] loaded into %@", [[NSBundle mainBundle] bundleIdentifier]);
            return orig$applicationDidFinishLaunching(self, _cmd, application, launchOptions);
        }

        __attribute__((constructor))
        static void \(name)Init(void) {
            Class cls = objc_getClass("UIApplication");
            if (!cls) {
                return;
            }
            MSHookMessageEx(cls,
                            @selector(application:didFinishLaunchingWithOptions:),
                            (IMP)&hook$applicationDidFinishLaunching,
                            (IMP *)&orig$applicationDidFinishLaunching);
        }

        """
    }

    private static func filterPlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>Filter</key>
        \t<dict>
        \t\t<key>Bundles</key>
        \t\t<array>
        \t\t\t<string>com.apple.springboard</string>
        \t\t</array>
        \t</dict>
        </dict>
        </plist>

        """
    }
}
