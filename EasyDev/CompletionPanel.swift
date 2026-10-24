//
//  CompletionPanel.swift
//  EasyDev
//

import AppKit

struct CompletionItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let insertText: String
    let isSnippet: Bool
    /// 匹配用的额外前缀（小写），例如 "%hook" 也能用 "hook" 触发。
    var extraPrefixes: [String] = []
}

/// 轻量补全面板：跟随光标显示候选列表，支持上下键选择、回车插入、Esc 关闭。
final class CompletionPanel: NSObject {

    private let panel: NSPanel
    private let tableView = NSTableView()
    private var items: [CompletionItem] = []
    private var onCommit: ((CompletionItem) -> Void)?

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        setup()
    }

    private func setup() {
        panel.level = .floating
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        panel.isMovable = false
        panel.hidesOnDeactivate = true
        panel.animationBehavior = .utilityWindow

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.width = 280
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.style = .plain
        tableView.backgroundColor = .windowBackgroundColor
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClick)

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .windowBackgroundColor
        scroll.borderType = .noBorder
        scroll.frame = NSRect(x: 0, y: 0, width: 280, height: 180)

        panel.contentView = scroll
    }

    var isVisible: Bool { panel.isVisible }

    func show(items: [CompletionItem], at screenPoint: NSPoint, onCommit: @escaping (CompletionItem) -> Void) {
        guard !items.isEmpty else { hide(); return }

        self.items = items
        self.onCommit = onCommit
        tableView.reloadData()

        let height = min(CGFloat(items.count) * 26 + 8, 240)
        let width: CGFloat = 280

        var origin = screenPoint
        origin.y -= height
        if let screen = NSScreen.main {
            if origin.y < screen.visibleFrame.minY {
                origin.y = screenPoint.y
            }
            if origin.x + width > screen.visibleFrame.maxX {
                origin.x = screen.visibleFrame.maxX - width
            }
        }

        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        tableView.scrollRowToVisible(0)
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
        items = []
    }

    /// 返回 true 表示事件已被面板消费。
    func handleKey(_ event: NSEvent) -> Bool {
        guard panel.isVisible else { return false }

        switch event.keyCode {
        case 125: move(1); return true
        case 126: move(-1); return true
        case 36, 76: commit(); return true
        case 53: hide(); return true
        case 48: commit(); return true
        default: return false
        }
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        var row = tableView.selectedRow
        if row < 0 { row = 0 }
        row = max(0, min(items.count - 1, row + delta))
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func commit() {
        let row = tableView.selectedRow
        guard row >= 0, row < items.count else { hide(); return }
        let item = items[row]
        hide()
        onCommit?(item)
    }

    @objc private func doubleClick() {
        commit()
    }
}

// MARK: - 数据源

extension CompletionPanel: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("cell")
        let cell: NSTableCellView

        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.imageScaling = .scaleProportionallyDown
            cell.addSubview(icon)
            cell.imageView = icon

            let label = NSTextField(labelWithString: "")
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label

            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 14),
                icon.heightAnchor.constraint(equalToConstant: 14),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        let item = items[row]
        cell.textField?.stringValue = item.title
        cell.imageView?.image = NSImage(
            systemSymbolName: item.isSnippet ? "text.badge.plus" : "textformat.abc",
            accessibilityDescription: nil
        )
        cell.imageView?.contentTintColor = item.isSnippet ? .systemPurple : .secondaryLabelColor
        return cell
    }
}
