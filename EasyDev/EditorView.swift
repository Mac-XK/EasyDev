//
//  EditorView.swift
//  EasyDev
//

import SwiftUI

struct EditorView: View {
    let project: TweakProject
    @EnvironmentObject private var app: AppState

    @State private var selectedFile: String?
    @State private var code: String = ""
    @State private var files: [String] = []
    @State private var saveTask: Task<Void, Never>?
    @State private var isDirty = false

    var body: some View {
        VStack(spacing: 0) {
            projectBar
            Divider()
            HSplitView {
                fileList
                    .frame(minWidth: 150, idealWidth: 185, maxWidth: 240)
                editor
                    .frame(minWidth: 400)
            }
        }
        .onAppear {
            reloadFiles()
            if selectedFile == nil { selectedFile = files.first }
            loadContent()
        }
        .onChange(of: project.id) { _, _ in
            selectedFile = nil
            reloadFiles()
            selectedFile = files.first
            loadContent()
        }
        .onChange(of: selectedFile) { _, _ in
            loadContent()
        }
        .onChange(of: code) { _, newValue in
            if !newValue.isEmpty { scheduleSave(newValue) }
        }
        .onDisappear {
            saveTask?.cancel()
            saveNow()
        }
    }

    // MARK: 顶部信息条

    private var projectBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: project.language.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.headline)
                Text(project.path.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            if isDirty {
                Text("未保存")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Text("\(project.language.rawValue) · \(project.scheme.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
    }

    // MARK: 文件列表

    private var fileList: some View {
        List(selection: $selectedFile) {
            Section("文件") {
                ForEach(files, id: \.self) { file in
                    HStack(spacing: 7) {
                        Image(systemName: iconFor(file))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 15)
                        Text(file)
                            .font(.callout)
                            .lineLimit(1)
                    }
                    .tag(file)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func iconFor(_ file: String) -> String {
        if file.hasSuffix(".swift") { return "swift" }
        if file.hasSuffix(".xmi") || file.hasSuffix(".xm") { return "chevron.left.forwardslash.chevron.right" }
        if file.hasSuffix(".m") || file.hasSuffix(".mm") { return "c.circle" }
        if file.hasSuffix(".h") { return "h.square" }
        if file.hasSuffix(".plist") { return "list.bullet.rectangle" }
        if file.hasPrefix("Makefile") { return "hammer" }
        return "doc"
    }

    // MARK: 编辑区

    private var editor: some View {
        CodeEditorView(text: $code, language: project.language)
            .disabled(selectedFile == nil)
            .overlay {
                if selectedFile == nil {
                    Text("选择一个文件")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
    }

    // MARK: 文件读写

    private func reloadFiles() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: project.path.path) else {
            files = []
            return
        }

        var result: [String] = []
        for item in items where !item.hasPrefix(".") {
            var isDir: ObjCBool = false
            let full = project.path.appendingPathComponent(item).path
            if fm.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue {
                result.append(item)
            }
        }

        // Makefile、control 放前面，其余按字母序
        result.sort { lhs, rhs in
            let priority = ["Makefile", "control"]
            let l = priority.firstIndex(of: lhs) ?? Int.max
            let r = priority.firstIndex(of: rhs) ?? Int.max
            if l != r { return l < r }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        files = result
    }

    private func loadContent() {
        guard let file = selectedFile else {
            code = ""
            return
        }
        let url = project.path.appendingPathComponent(file)
        code = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        isDirty = false
    }

    private func scheduleSave(_ text: String) {
        isDirty = true
        saveTask?.cancel()
        let file = selectedFile
        let dir = project.path

        saveTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let file else { return }
            let url = dir.appendingPathComponent(file)
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run { isDirty = false }
            } catch {
                await MainActor.run {
                    app.append(.error, "保存失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func saveNow() {
        guard isDirty, let file = selectedFile else { return }
        let url = project.path.appendingPathComponent(file)
        try? code.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
    }
}

#Preview {
    EditorView(
        project: TweakProject(
            name: "MyTweak",
            path: URL(fileURLWithPath: "/tmp/MyTweak"),
            language: .logos,
            scheme: .rootless
        )
    )
    .environmentObject(AppState())
    .frame(width: 900, height: 600)
}
