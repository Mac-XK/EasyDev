//
//  WelcomeView.swift
//  EasyDev
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.tint)

                Text("EasyDev")
                    .font(.largeTitle.weight(.semibold))

                Text("iOS Tweak 开发环境")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                ActionCard(
                    icon: "plus.square.on.square",
                    title: "新建项目",
                    subtitle: "从模板创建 Tweak"
                ) { app.isShowingNewProject = true }

                ActionCard(
                    icon: "shippingbox",
                    title: "Theos 环境",
                    subtitle: "安装或切换环境"
                ) { app.sidebarSelection = .environments }

                ActionCard(
                    icon: "checklist",
                    title: "依赖检查",
                    subtitle: "git / ldid / dpkg"
                ) { app.sidebarSelection = .dependencies }
            }

            if !app.projects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近项目")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(app.projects.prefix(4)) { project in
                        Button {
                            app.selectProject(project)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: project.language.icon)
                                    .foregroundStyle(.tint)
                                    .frame(width: 20)
                                Text(project.name)
                                Spacer()
                                Text(project.path.deletingLastPathComponent().path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 460)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

private struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 140, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(hovering ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState())
        .frame(width: 900, height: 600)
}
