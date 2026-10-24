//
//  EasyDevApp.swift
//  EasyDev
//

import SwiftUI

@main
struct EasyDevApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
                .frame(minWidth: 1200, minHeight: 780)
        }
        .defaultSize(width: 1480, height: 940)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建项目…") { app.isShowingNewProject = true }
                    .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("构建") {
                Button("构建") { app.build() }
                    .keyboardShortcut("b", modifiers: .command)
                Button("清理日志") { app.clearLogs() }
                Divider()
                Toggle("显示构建日志", isOn: $app.isLogVisible)
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}
