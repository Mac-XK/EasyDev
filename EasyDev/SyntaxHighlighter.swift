//
//  SyntaxHighlighter.swift
//  EasyDev
//

import AppKit

/// 基于正则的轻量语法高亮，覆盖 Logos / Objective-C / C++。
enum SyntaxHighlighter {

    struct Rule {
        let pattern: String
        let color: NSColor
        let bold: Bool
        let options: NSRegularExpression.Options

        init(_ pattern: String, _ color: NSColor, bold: Bool = false, options: NSRegularExpression.Options = []) {
            self.pattern = pattern
            self.color = color
            self.bold = bold
            self.options = options
        }
    }

    // MARK: - 颜色

    private static var keywordColor: NSColor { .systemPurple }
    private static var logosColor: NSColor { .systemPink }
    private static var stringColor: NSColor { .systemRed }
    private static var commentColor: NSColor { .secondaryLabelColor }
    private static var numberColor: NSColor { .systemBlue }
    private static var preprocessorColor: NSColor { .systemBrown }
    private static var typeColor: NSColor { .systemTeal }
    private static var objcColor: NSColor { .systemIndigo }

    // MARK: - 规则

    private static let cKeywords = [
        "void", "int", "char", "short", "long", "float", "double", "signed", "unsigned",
        "BOOL", "id", "SEL", "IMP", "Class", "self", "super", "nil", "Nil", "NULL", "YES", "NO",
        "return", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
        "static", "extern", "const", "volatile", "inline", "typedef", "struct", "union", "enum",
        "sizeof", "goto", "register", "auto",
        "class", "namespace", "template", "typename", "using", "public", "private", "protected",
        "virtual", "override", "final", "new", "delete", "try", "catch", "throw", "operator",
        "nullptr", "constexpr", "noexcept", "explicit", "friend", "mutable", "this"
    ]

    private static let objcKeywords = [
        "@interface", "@implementation", "@end", "@protocol", "@property", "@synthesize",
        "@dynamic", "@selector", "@encode", "@synchronized", "@autoreleasepool", "@try",
        "@catch", "@finally", "@throw", "@class", "@import", "@available", "@optional",
        "@required", "@public", "@private", "@protected", "@package"
    ]

    static let logosKeywords = [
        "%hook", "%end", "%group", "%ctor", "%dtor", "%init", "%orig", "%new",
        "%property", "%subclass", "%config", "%log", "%hookf", "%c"
    ]

    private static func rules() -> [Rule] {
        var rules: [Rule] = []

        // 注释
        rules.append(Rule(#"//[^\n]*"#, commentColor, options: .anchorsMatchLines))
        rules.append(Rule(#"/\*[\s\S]*?\*/"#, commentColor))

        // 字符串
        rules.append(Rule(#""(?:\\.|[^"\\])*""#, stringColor))
        rules.append(Rule(#"'(?:\\.|[^'\\])*'"#, stringColor))

        // 预处理
        rules.append(Rule(#"^\s*#(?:import|include|define|if|ifdef|ifndef|else|elif|endif|pragma|undef)\b"#,
                          preprocessorColor, bold: true, options: .anchorsMatchLines))

        // Logos 关键字（优先，用最长匹配）
        let logosPattern = logosKeywords
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        rules.append(Rule("(?:\(logosPattern))", logosColor, bold: true))

        // ObjC 关键字
        let objcPattern = objcKeywords
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        rules.append(Rule("(?:\(objcPattern))\\b", objcColor, bold: true))

        // C / C++ 关键字
        let cPattern = cKeywords
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        rules.append(Rule("\\b(?:\(cPattern))\\b", keywordColor))

        // 数字
        rules.append(Rule(#"\b(?:0[xX][0-9a-fA-F]+|\d+(?:\.\d+)?)\b"#, numberColor))

        return rules
    }

    private static let compiled: [(NSRegularExpression, Rule)] = {
        rules().compactMap { rule in
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else {
                return nil
            }
            return (regex, rule)
        }
    }()

    // MARK: - 应用

    static func highlight(_ storage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        storage.beginEditing()

        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        storage.addAttribute(.font, value: EditorTheme.font, range: fullRange)

        let text = storage.string

        for (regex, rule) in compiled {
            regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match else { return }
                storage.addAttribute(.foregroundColor, value: rule.color, range: match.range)
                if rule.bold {
                    storage.addAttribute(.font, value: EditorTheme.boldFont, range: match.range)
                }
            }
        }

        storage.endEditing()
    }
}

enum EditorTheme {
    static let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    static let boldFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .semibold)
    static let lineHeight: CGFloat = 1.35
}
