//
//  DependenciesView.swift
//  EasyDev
//

import SwiftUI

struct DependenciesView: View {
    @EnvironmentObject private var app: AppState

    private var installedCount: Int {
        app.dependencies.filter(\.installed).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                dependencyList
                footer
            }
            .padding(28)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("依赖检查")
                .font(.title2.weight(.semibold))
            Text("Theos 编译 Tweak 所需的命令行工具，来自当前 PATH。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var dependencyList: some View {
        VStack(spacing: 0) {
            ForEach(Array(app.dependencies.enumerated()), id: \.element.id) { index, dep in
                DependencyRow(dependency: dep)

                if index < app.dependencies.count - 1 {
                    Divider().padding(.leading, 42)
                }
            }

            if app.dependencies.isEmpty {
                Text("正在检测…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("\(installedCount)/\(app.dependencies.count) 已安装")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !app.missingRequiredDependencies.isEmpty {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("缺少 \(app.missingRequiredDependencies.count) 个必需依赖")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            Button("重新检测") {
                app.refresh()
            }
            .controlSize(.small)
        }
    }
}

// MARK: - 依赖行

private struct DependencyRow: View {
    let dependency: DependencyInfo

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                nameLine
                Text(dependency.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            pathText

            Text(versionText)
                .font(.caption2)
                .fontDesign(.monospaced)
                .foregroundStyle(versionColor)
                .frame(width: 68, alignment: .trailing)

            if !dependency.installed {
                Button("安装") {}
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
    }

    private var statusIcon: some View {
        Image(systemName: dependency.installed ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(dependency.installed ? Color.green : Color.red)
            .font(.system(size: 14))
            .frame(width: 16)
    }

    private var nameLine: some View {
        HStack(spacing: 6) {
            Text(dependency.name)
                .font(.callout.weight(.medium))
                .fontDesign(.monospaced)

            if dependency.required {
                Text("必需")
                    .font(.system(size: 9))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var pathText: some View {
        if let path = dependency.path {
            Text(path)
                .font(.caption2)
                .fontDesign(.monospaced)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: 220, alignment: .trailing)
        }
    }

    private var versionText: String {
        if let version = dependency.version {
            return version
        }
        return dependency.installed ? "—" : "未安装"
    }

    private var versionColor: Color {
        dependency.installed ? .secondary : .red
    }
}

#Preview {
    DependenciesView()
        .environmentObject(AppState())
        .frame(width: 820, height: 640)
}
