//
//  CodeEditorView.swift
//  EasyDev
//

import SwiftUI
import AppKit

/// 基于 NSTextView 的代码编辑器：语法高亮 + 自建补全面板。
struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var language: TweakLanguage

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = EditorTextView()
        textView.isRichText = true
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true

        textView.font = EditorTheme.font
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 10, height: 10)

        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        if let container = textView.textContainer {
            container.widthTracksTextView = false
            container.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        textView.delegate = context.coordinator
        textView.string = text

        let coordinator = context.coordinator
        textView.keyHandler = { event in
            coordinator.panel.handleKey(event)
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView

        DispatchQueue.main.async {
            if let storage = textView.textStorage {
                SyntaxHighlighter.highlight(storage)
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        guard textView.string != text else { return }

        let selection = textView.selectedRange()
        textView.string = text
        let length = (text as NSString).length
        if selection.location <= length {
            textView.setSelectedRange(NSRange(location: selection.location, length: 0))
        }
        if let storage = textView.textStorage {
            SyntaxHighlighter.highlight(storage)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        weak var textView: NSTextView?
        let panel = CompletionPanel()

        private var suppressCompletion = false

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            let value = textView.string
            if parent.text != value {
                parent.text = value
            }

            if let storage = textView.textStorage {
                SyntaxHighlighter.highlight(storage)
            }

            if suppressCompletion {
                suppressCompletion = false
                return
            }

            updateCompletions(in: textView)
        }

        // MARK: 补全

        private func updateCompletions(in textView: NSTextView) {
            guard let context = prefixContext(in: textView) else {
                panel.hide()
                return
            }

            let lowerPrefix = context.prefix.lowercased()

            var seen = Set<String>()
            var results: [CompletionItem] = []

            for item in Self.allItems {
                guard !seen.contains(item.title) else { continue }

                let titleMatch = item.title.lowercased().hasPrefix(lowerPrefix)
                let extraMatch = item.extraPrefixes.contains {
                    $0.lowercased().hasPrefix(lowerPrefix)
                }

                guard titleMatch || extraMatch else { continue }
                guard item.title.lowercased() != lowerPrefix else { continue }

                seen.insert(item.title)
                results.append(item)
            }

            guard !results.isEmpty else {
                panel.hide()
                return
            }

            // 优先展示整段片段
            results.sort { lhs, rhs in
                if lhs.isSnippet != rhs.isSnippet { return lhs.isSnippet }
                return lhs.title < rhs.title
            }

            let cursorRange = NSRange(location: textView.selectedRange().location, length: 0)
            let rect = textView.firstRect(forCharacterRange: cursorRange, actualRange: nil)
            let items = Array(results.prefix(10))
            let range = context.range

            panel.show(
                items: items,
                at: NSPoint(x: rect.minX, y: rect.minY)
            ) { [weak self, weak textView] item in
                guard let self, let textView else { return }
                self.suppressCompletion = true
                if item.isSnippet {
                    self.insertSnippet(item.insertText, in: textView, replacing: range)
                } else {
                    textView.insertText(item.insertText, replacementRange: range)
                }
                self.panel.hide()
            }
        }

        /// 插入片段，并选中第一个 <#占位符#>。
        private func insertSnippet(_ body: String, in textView: NSTextView, replacing range: NSRange) {
            var result = ""
            var placeholder: NSRange?
            var index = body.startIndex

            while index < body.endIndex {
                if body[index...].hasPrefix("<#"),
                   let endRange = body[index...].range(of: "#>") {
                    let start = body.index(index, offsetBy: 2)
                    let content = String(body[start..<endRange.lowerBound])
                    let location = (result as NSString).length
                    if placeholder == nil {
                        placeholder = NSRange(location: location, length: (content as NSString).length)
                    }
                    result += content
                    index = endRange.upperBound
                } else {
                    result.append(body[index])
                    index = body.index(after: index)
                }
            }

            textView.insertText(result, replacementRange: range)

            if let placeholder {
                let absolute = NSRange(
                    location: range.location + placeholder.location,
                    length: placeholder.length
                )
                if absolute.location + absolute.length <= (textView.string as NSString).length {
                    textView.setSelectedRange(absolute)
                }
            }
        }

        /// 取出光标前的单词前缀及其范围。
        private func prefixContext(in textView: NSTextView) -> (prefix: String, range: NSRange)? {
            let ns = textView.string as NSString
            let cursor = textView.selectedRange().location
            guard cursor > 0, cursor <= ns.length else { return nil }

            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "%_@"))
            let disallowed = allowed.inverted

            var start = cursor
            while start > 0 {
                let ch = ns.substring(with: NSRange(location: start - 1, length: 1))
                if ch.rangeOfCharacter(from: disallowed) != nil {
                    break
                }
                start -= 1
            }

            let length = cursor - start
            guard length > 0, length < 40 else { return nil }

            if length == 1 {
                let previous = start > 0 ? ns.substring(with: NSRange(location: start - 1, length: 1)) : ""
                if previous != "%" && previous != "@" {
                    return nil
                }
            }

            let prefix = ns.substring(with: NSRange(location: start, length: length))
            return (prefix, NSRange(location: start, length: length))
        }

        // MARK: 候选

        static let allItems: [CompletionItem] = buildItems()

        private static func buildItems() -> [CompletionItem] {
            var items: [CompletionItem] = []

            // 整段片段
            items += [
                CompletionItem(
                    title: "%hook … %end",
                    insertText: "%hook <#ClassName#>\n\n%end",
                    isSnippet: true,
                    extraPrefixes: ["hook"]
                ),
                CompletionItem(
                    title: "%ctor { %init; }",
                    insertText: "%ctor {\n    %init;\n}",
                    isSnippet: true,
                    extraPrefixes: ["ctor"]
                ),
                CompletionItem(
                    title: "%group … %end",
                    insertText: "%group <#GroupName#>\n\n%end",
                    isSnippet: true,
                    extraPrefixes: ["group"]
                ),
                CompletionItem(
                    title: "%subclass … %end",
                    insertText: "%subclass <#ClassName#> : <#SuperClass#> {\n\n}\n\n%end",
                    isSnippet: true,
                    extraPrefixes: ["subclass"]
                ),
                CompletionItem(
                    title: "%property …",
                    insertText: "%property (nonatomic, strong) id <#name#>;",
                    isSnippet: true,
                    extraPrefixes: ["property"]
                ),
                CompletionItem(
                    title: "#import …",
                    insertText: "#import <#Foundation/Foundation.h#>",
                    isSnippet: true,
                    extraPrefixes: ["import", "include"]
                )
            ]

            // 单个关键字
            for keyword in SyntaxHighlighter.logosKeywords {
                let bare = keyword.hasPrefix("%") ? String(keyword.dropFirst()) : keyword
                items.append(
                    CompletionItem(
                        title: keyword,
                        insertText: keyword,
                        isSnippet: false,
                        extraPrefixes: [bare]
                    )
                )
            }

            let objc = [
                "@interface", "@implementation", "@end", "@property", "@selector",
                "@synchronized", "@autoreleasepool", "@try", "@catch", "@finally",
                "#import", "#include", "#define", "#if", "#ifdef", "#ifndef", "#endif"
            ]
            for word in objc {
                items.append(CompletionItem(title: word, insertText: word, isSnippet: false))
            }

            let cWords = [
                "void", "int", "char", "BOOL", "id", "SEL", "IMP", "Class",
                "self", "super", "nil", "NULL", "YES", "NO",
                "return", "if", "else", "for", "while", "switch", "case", "break", "continue",
                "static", "extern", "const", "typedef", "struct", "enum",
                "class", "namespace", "template", "using", "public", "private", "protected",
                "new", "delete", "try", "catch", "throw", "nullptr"
            ]
            for word in cWords {
                items.append(CompletionItem(title: word, insertText: word, isSnippet: false))
            }

            let symbols = [
                "UIApplication", "UIView", "UIViewController", "NSObject", "NSString",
                "NSDictionary", "NSArray", "NSBundle", "NSLog", "objc_getClass",
                "MSHookMessageEx", "MSHookFunction", "class_getInstanceMethod",
                "method_exchangeImplementations", "objc_msgSend"
            ]
            for word in symbols {
                items.append(CompletionItem(title: word, insertText: word, isSnippet: false))
            }

            return items
        }
    }
}

/// 拦截键盘事件，让补全面板优先处理。
final class EditorTextView: NSTextView {
    var keyHandler: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true { return }
        super.keyDown(with: event)
    }
}
