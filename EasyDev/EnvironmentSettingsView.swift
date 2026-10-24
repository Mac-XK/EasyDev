//
//  EnvironmentSettingsView.swift
//  EasyDev
//

import SwiftUI

struct EnvironmentSettingsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(app.environments) { env in
                    EnvironmentCard(environment: env)
                }

                installCard
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
            Text("Theos 环境")
                .font(.title2.weight(.semibold))
            Text("管理和切换编译 Tweak 所用的 Theos 工具链。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var installCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("安装新环境")
                    .font(.headline)
                Spacer()
                if app.installingKind != nil {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("安装中…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                InstallButton(
                    title: "标准 Theos",
                    subtitle: "theos/theos",
                    icon: "shippingbox",
                    isInstalling: app.installingKind == .standard,
                    disabled: app.installingKind != nil
                ) {
                    app.installEnvironment(.standard)
                }

                InstallButton(
                    title: "RootHide Theos",
                    subtitle: "roothide/theos",
                    icon: "eye.slash",
                    isInstalling: app.installingKind == .rootHide,
                    disabled: app.installingKind != nil
                ) {
                    app.installEnvironment(.rootHide)
                }
            }

            Text("安装到 ~/Library/Application Support/EasyDev/，需要网络代理时请在设置中配置。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }
}

// MARK: - 环境卡片

private struct EnvironmentCard: View {
    let environment: TheosEnvironment
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: environment.kind.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(environment.isAvailable ? Color.accentColor : Color.secondary)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.name)
                        .font(.headline)
                    Text(environment.path.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                statusBadge
            }

            if environment.isAvailable {
                Divider()
                SDKSection(environment: environment)
            } else {
                unavailableRow
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(environment.isAvailable ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(environment.isAvailable ? "可用" : "缺失")
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }

    private var unavailableRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("未安装")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("安装") {
                app.installEnvironment(environment.kind)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(app.installingKind != nil)
        }
    }
}

// MARK: - SDK 选择

private struct SDKSection: View {
    let environment: TheosEnvironment
    @EnvironmentObject private var app: AppState

    private var selectedVersion: String? {
        app.sdkVersion(for: environment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SDK")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let selected = selectedVersion {
                    Text("当前 \(selected)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if let latest = environment.latestSDK {
                    Text("最新 \(latest)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if environment.sdkVersions.isEmpty {
                Text("尚未安装 SDK")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(environment.sdkVersions.reversed(), id: \.self) { version in
                        SDKPill(
                            version: version,
                            isSelected: selectedVersion == version
                        ) {
                            app.selectSDK(version, for: environment)
                        }
                    }
                }
            }
        }
    }
}

private struct SDKPill: View {
    let version: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("iOS \(version)")
                .font(.caption2.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(
                        isSelected
                        ? Color.accentColor.opacity(0.9)
                        : Color.primary.opacity(0.06)
                    )
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .help("使用 iOS \(version) SDK 编译")
    }
}

// MARK: - 安装按钮

private struct InstallButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isInstalling: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(disabled && !isInstalling ? Color.secondary : Color.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isInstalling {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(disabled ? 0.02 : 0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - 流式布局

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    EnvironmentSettingsView()
        .environmentObject(AppState())
        .frame(width: 1000, height: 760)
}
