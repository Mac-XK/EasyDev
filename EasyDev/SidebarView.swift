//
//  SidebarView.swift
//  EasyDev
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        List(selection: $app.sidebarSelection) {
            Label("首页", systemImage: "house")
                .tag(AppState.SidebarItem.home)

            Section("项目") {
                ForEach(app.projects) { project in
                    ProjectRow(project: project)
                        .tag(AppState.SidebarItem.project(project.id))
                        .contextMenu {
                            Button("构建") {
                                app.selectProject(project)
                                app.build()
                            }
                            Button("在 Finder 中显示") {
                                NSWorkspace.shared.activateFileViewerSelecting([project.path])
                            }
                            Divider()
                            Button("移除项目", role: .destructive) {}
                        }
                }

                Button {
                    app.isShowingNewProject = true
                } label: {
                    Label("新建项目…", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)

                Button {
                    app.openProjectPanel()
                } label: {
                    Label("打开项目…", systemImage: "folder")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }

            Section("工具") {
                Label("Theos 环境", systemImage: "shippingbox")
                    .tag(AppState.SidebarItem.environments)
                Label("依赖检查", systemImage: "checklist")
                    .tag(AppState.SidebarItem.dependencies)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusFooter()
        }
    }
}

// MARK: - 项目行

private struct ProjectRow: View {
    let project: TweakProject

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: project.language.icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.callout)
                    .lineLimit(1)
                Text("\(project.language.rawValue) · \(project.scheme.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 底部状态

private struct StatusFooter: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(app.activeEnvironment == nil ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text(app.activeEnvironment?.name ?? "未配置 Theos")
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                if let env = app.activeEnvironment,
                   let sdk = app.sdkVersion(for: env) {
                    Text("SDK \(sdk)")
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "iphone")
                        .font(.system(size: 9))
                    Text(app.selectedDevice?.name ?? "无设备")
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.tertiary)
            }
            .font(.caption2)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppState())
        .frame(width: 230, height: 600)
}
