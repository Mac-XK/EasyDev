//
//  NewProjectView.swift
//  EasyDev
//

import SwiftUI
import AppKit

struct NewProjectView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = "MyTweak"
    @State private var parentDirectory = ProjectCreator.defaultParentDirectory()
    @State private var template: ProjectTemplate = .tweak
    @State private var scheme: PackageScheme = .rootless
    @State private var environmentID: TheosEnvironment.ID?
    @State private var sdkVersion: String?
    @State private var bundlePrefix = "com.yourcompany"
    @State private var errorMessage: String?
    @State private var isCreating = false

    private var selectedEnvironment: TheosEnvironment? {
        if let id = environmentID, let env = app.environments.first(where: { $0.id == id }) {
            return env
        }
        return app.activeEnvironment
    }

    private var sdkVersions: [String] {
        selectedEnvironment?.sdkVersions.reversed() ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 580)
        .onAppear {
            if environmentID == nil {
                environmentID = app.activeEnvironment?.id
            }
            if sdkVersion == nil, let env = selectedEnvironment {
                sdkVersion = app.sdkVersion(for: env)
            }
        }
        .onChange(of: environmentID) { _, _ in
            sdkVersion = selectedEnvironment.flatMap { app.sdkVersion(for: $0) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.square.on.square")
                .font(.system(size: 22))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("新建项目")
                    .font(.headline)
                Text("使用 Theos 模板创建项目，支持 16 种类型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                row("名称") {
                    TextField("MyTweak", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                row("位置") {
                    HStack(spacing: 8) {
                        Text(parentDirectory.path)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("选择…") { chooseDirectory() }
                    }
                }

                row("类型") {
                    Picker("", selection: $template) {
                        ForEach(ProjectTemplate.grouped, id: \.group) { section in
                            Section(section.group) {
                                ForEach(section.templates) { item in
                                    Text(item.displayName).tag(item)
                                }
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                row("打包方案") {
                    Picker("", selection: $scheme) {
                        ForEach(PackageScheme.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                row("Theos 环境") {
                    Picker("", selection: $environmentID) {
                        ForEach(app.environments) { env in
                            Text("\(env.name) — \(env.path.lastPathComponent)")
                                .tag(Optional(env.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                row("SDK") {
                    Picker("", selection: $sdkVersion) {
                        ForEach(sdkVersions, id: \.self) { v in
                            Text("iOS \(v)").tag(Optional(v))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(sdkVersions.isEmpty)
                }

                row("Bundle 前缀") {
                    TextField("com.yourcompany", text: $bundlePrefix)
                        .textFieldStyle(.roundedBorder)
                }

                if let errorMessage {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxHeight: 460)
    }

    private var footer: some View {
        HStack {
            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            if isCreating {
                ProgressView().controlSize(.small)
            }

            Button("创建") { create() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isCreating || name.trimmingCharacters(in: .whitespaces).isEmpty || selectedEnvironment == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .trailing)
            content()
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择项目存放目录"

        if panel.runModal() == .OK, let url = panel.url {
            parentDirectory = url
        }
    }

    private func create() {
        guard let env = selectedEnvironment else {
            errorMessage = "请先选择可用的 Theos 环境"
            return
        }

        errorMessage = nil
        isCreating = true

        let options = ProjectCreator.Options(
            name: name,
            parentDirectory: parentDirectory,
            template: template,
            scheme: scheme,
            sdkVersion: sdkVersion,
            bundlePrefix: bundlePrefix.isEmpty ? "com.yourcompany" : bundlePrefix,
            theosPath: env.path
        )

        // nic.pl 是阻塞调用，放到后台执行
        Task.detached {
            do {
                let url = try ProjectCreator.create(options)
                await MainActor.run {
                    app.addProject(at: url)
                    app.append(.success, "已创建 \(template.displayName)：\(url.path)")
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NewProjectView()
        .environmentObject(AppState())
}
