//
//  BuildLogView.swift
//  EasyDev
//

import SwiftUI

struct BuildLogView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(app.logs) { line in
                            LogRow(line: line)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: app.logs.count) { _, _ in
                    if let last = app.logs.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            statusIndicator

            Text(app.buildStatus.label)
                .font(.caption.weight(.medium))

            Spacer()

            Text("\(app.logs.count) 条")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider().frame(height: 14)

            Button {
                app.revealArtifacts()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .disabled(app.selectedProject == nil)
            .help("在 Finder 中显示产物")

            Button {
                app.clearLogs()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("清空日志")

            Button {
                app.isLogVisible = false
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .help("隐藏日志")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch app.buildStatus {
        case .idle:
            Circle().fill(.secondary).frame(width: 7, height: 7)
        case .building:
            ProgressView().controlSize(.mini)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 11))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 11))
        }
    }
}

// MARK: - 单行日志

private struct LogRow: View {
    let line: LogLine

    private var color: Color {
        switch line.level {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .command: return .accentColor
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Text(line.timestamp, format: .dateTime.hour().minute().second())
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 58, alignment: .leading)

            Image(systemName: line.level.symbol)
                .font(.system(size: 9))
                .foregroundStyle(color)
                .frame(width: 12)
                .padding(.top, 2)

            Text(line.text)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(line.level == .command ? Color.accentColor : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    BuildLogView()
        .environmentObject(AppState())
        .frame(width: 900, height: 190)
}
