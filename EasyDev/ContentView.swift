//
//  ContentView.swift
//  EasyDev
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var app: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 270)
        } detail: {
            VStack(spacing: 0) {
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if app.isLogVisible {
                    Divider()
                    BuildLogView()
                        .frame(height: 200)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(navigationTitle)
            .navigationSubtitle(subtitle)
            .toolbar { toolbarContent }
            .animation(.snappy(duration: 0.22), value: app.isLogVisible)
        }
        .onAppear {
            if app.sidebarSelection == nil {
                app.sidebarSelection = .home
            }
        }
        .sheet(isPresented: $app.isShowingNewProject) {
            NewProjectView()
                .environmentObject(app)
        }
    }

    // MARK: 主内容

    @ViewBuilder
    private var detailContent: some View {
        switch app.sidebarSelection {
        case .home:
            WelcomeView()
        case .project(let id):
            if let project = app.projects.first(where: { $0.id == id }) {
                EditorView(project: project)
            } else {
                WelcomeView()
            }
        case .environments:
            EnvironmentSettingsView()
        case .dependencies:
            DependenciesView()
        case nil:
            WelcomeView()
        }
    }

    private var navigationTitle: String {
        switch app.sidebarSelection {
        case .home:
            return "EasyDev"
        case .project(let id):
            return app.projects.first(where: { $0.id == id })?.name ?? "EasyDev"
        case .environments:
            return "Theos 环境"
        case .dependencies:
            return "依赖检查"
        case nil:
            return "EasyDev"
        }
    }

    private var subtitle: String {
        switch app.sidebarSelection {
        case .project(let id):
            guard let p = app.projects.first(where: { $0.id == id }) else { return "" }
            return "\(p.language.rawValue) · \(p.scheme.displayName)"
        default:
            return ""
        }
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                // 新建项目向导
            } label: {
                Image(systemName: "plus")
            }
            .help("新建项目 (⌘N)")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if app.buildStatus.isBusy {
                Button {
                    app.cancelBuild()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .help("停止构建")
            } else {
                Button {
                    app.build()
                } label: {
                    Image(systemName: "hammer.fill")
                }
                .disabled(app.selectedProject == nil)
                .keyboardShortcut("b", modifiers: .command)
                .help("构建 (⌘B)")
            }

            Menu {
                if app.devices.isEmpty {
                    Text("未检测到设备")
                } else {
                    ForEach(app.devices) { device in
                        Button {
                            app.selectedDeviceID = device.id
                        } label: {
                            if app.selectedDeviceID == device.id {
                                Label("\(device.name) · \(device.osVersion)", systemImage: "checkmark")
                            } else {
                                Text("\(device.name) · \(device.osVersion)")
                            }
                        }
                    }
                }
                Divider()
                Button("安装到设备") {}
                    .disabled(app.selectedProject == nil)
                Button("刷新设备列表") {}
            } label: {
                Image(systemName: app.selectedDevice == nil ? "iphone.slash" : "iphone")
            }
            .help("设备")

            Button {
                app.isLogVisible.toggle()
            } label: {
                Image(systemName: app.isLogVisible ? "rectangle.bottomthird.inset.filled" : "rectangle.bottomthird.inset")
            }
            .help("显示/隐藏构建日志 (⇧⌘L)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1280, height: 800)
}
