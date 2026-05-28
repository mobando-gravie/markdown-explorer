import AppKit
import Foundation
import JavaScriptCore

final class SyntaxHighlighter: @unchecked Sendable {
    static let shared = SyntaxHighlighter()

    private let lock = NSLock()
    private var context: JSContext?
    private var loaded = false

    private init() {}

    func highlight(_ code: String, language: String?, isDarkMode: Bool) -> NSAttributedString {
        lock.lock()
        defer { lock.unlock() }
        ensureLoaded()
        guard let context else { return plain(code, isDarkMode: isDarkMode) }

        context.setObject(code, forKeyedSubscript: "__src" as NSString)
        context.setObject(language as Any, forKeyedSubscript: "__lang" as NSString)

        let script: String
        if let language, !language.isEmpty, !language.lowercased().hasPrefix("mermaid") {
            script = """
            (function() {
              try {
                if (hljs.getLanguage(__lang)) {
                  return hljs.highlight(__src, { language: __lang, ignoreIllegals: true }).value;
                }
                return hljs.highlightAuto(__src).value;
              } catch (e) { return null; }
            })();
            """
        } else {
            script = """
            (function() {
              try { return hljs.highlightAuto(__src).value; }
              catch (e) { return null; }
            })();
            """
        }

        guard let html = context.evaluateScript(script)?.toString(), !html.isEmpty, html != "undefined" else {
            return plain(code, isDarkMode: isDarkMode)
        }
        return parse(html, isDarkMode: isDarkMode) ?? plain(code, isDarkMode: isDarkMode)
    }

    private func ensureLoaded() {
        guard !loaded else { return }
        guard let url = Bundle.main.url(forResource: "highlight.min", withExtension: "js"),
              let js = try? String(contentsOf: url, encoding: .utf8),
              let ctx = JSContext()
        else { return }
        ctx.evaluateScript(js)
        self.context = ctx
        self.loaded = true
    }

    private func plain(_ code: String, isDarkMode: Bool) -> NSAttributedString {
        NSAttributedString(string: code, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
            .foregroundColor: HLJSPalette(isDarkMode: isDarkMode).defaultText
        ])
    }

    private func parse(_ html: String, isDarkMode: Bool) -> NSAttributedString? {
        let palette = HLJSPalette(isDarkMode: isDarkMode)
        let result = NSMutableAttributedString()
        var stack: [NSColor] = []
        var i = html.startIndex
        var buf = ""

        func flush() {
            guard !buf.isEmpty else { return }
            let unescaped = Self.unescape(buf)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
                .foregroundColor: stack.last ?? palette.defaultText
            ]
            result.append(NSAttributedString(string: unescaped, attributes: attrs))
            buf = ""
        }

        while i < html.endIndex {
            let ch = html[i]
            if ch == "<" {
                flush()
                guard let close = html[i...].firstIndex(of: ">") else { break }
                let tag = String(html[i...close])
                i = html.index(after: close)
                if tag.hasPrefix("</") {
                    if !stack.isEmpty { stack.removeLast() }
                } else if tag.hasPrefix("<span") {
                    let cls = Self.classAttribute(of: tag)
                    let color = palette.color(forHLJSClass: cls) ?? stack.last ?? palette.defaultText
                    stack.append(color)
                }
                continue
            }
            buf.append(ch)
            i = html.index(after: i)
        }
        flush()
        return result.length > 0 ? result : nil
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#x27;", with: "'")
         .replacingOccurrences(of: "&#39;", with: "'")
         .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func classAttribute(of tag: String) -> String {
        guard let range = tag.range(of: #"class="[^"]+""#, options: .regularExpression) else { return "" }
        let kv = tag[range]
        return String(kv.dropFirst(7).dropLast())
    }
}

private struct HLJSPalette {
    let defaultText: NSColor
    let keyword: NSColor
    let string: NSColor
    let number: NSColor
    let comment: NSColor
    let title: NSColor
    let builtin: NSColor
    let attr: NSColor
    let tag: NSColor
    let type: NSColor
    let variable: NSColor

    init(isDarkMode: Bool) {
        if isDarkMode {
            defaultText = NSColor(white: 0.90, alpha: 1)
            keyword     = NSColor(red: 0.94, green: 0.45, blue: 0.55, alpha: 1)  // pinkish-red
            string      = NSColor(red: 0.66, green: 0.86, blue: 0.50, alpha: 1)  // green
            number      = NSColor(red: 0.95, green: 0.65, blue: 0.40, alpha: 1)  // orange
            comment     = NSColor(white: 0.55, alpha: 1)
            title       = NSColor(red: 0.55, green: 0.78, blue: 1.00, alpha: 1)  // blue
            builtin     = NSColor(red: 0.50, green: 0.85, blue: 0.85, alpha: 1)  // teal
            attr        = NSColor(red: 0.95, green: 0.78, blue: 0.40, alpha: 1)  // yellow
            tag         = NSColor(red: 0.95, green: 0.55, blue: 0.55, alpha: 1)
            type        = NSColor(red: 0.62, green: 0.78, blue: 1.00, alpha: 1)
            variable    = NSColor(red: 0.90, green: 0.70, blue: 0.85, alpha: 1)
        } else {
            defaultText = NSColor(white: 0.12, alpha: 1)
            keyword     = NSColor(red: 0.85, green: 0.12, blue: 0.30, alpha: 1)
            string      = NSColor(red: 0.06, green: 0.45, blue: 0.20, alpha: 1)
            number      = NSColor(red: 0.69, green: 0.32, blue: 0.05, alpha: 1)
            comment     = NSColor(white: 0.45, alpha: 1)
            title       = NSColor(red: 0.13, green: 0.32, blue: 0.66, alpha: 1)
            builtin     = NSColor(red: 0.08, green: 0.46, blue: 0.46, alpha: 1)
            attr        = NSColor(red: 0.55, green: 0.40, blue: 0.08, alpha: 1)
            tag         = NSColor(red: 0.65, green: 0.18, blue: 0.18, alpha: 1)
            type        = NSColor(red: 0.10, green: 0.36, blue: 0.60, alpha: 1)
            variable    = NSColor(red: 0.50, green: 0.30, blue: 0.50, alpha: 1)
        }
    }

    func color(forHLJSClass cls: String) -> NSColor? {
        let primary = cls.split(separator: " ").first.map(String.init) ?? cls
        switch primary {
        case "hljs-keyword", "hljs-selector-tag", "hljs-operator", "hljs-link":
            return keyword
        case "hljs-string", "hljs-regexp", "hljs-quote":
            return string
        case "hljs-number", "hljs-literal":
            return number
        case "hljs-comment", "hljs-meta-keyword", "hljs-doctag":
            return comment
        case "hljs-title", "hljs-section", "hljs-name", "hljs-selector-id", "hljs-selector-class":
            return title
        case "hljs-built_in", "hljs-builtin-name", "hljs-symbol":
            return builtin
        case "hljs-attr", "hljs-attribute", "hljs-property":
            return attr
        case "hljs-tag":
            return tag
        case "hljs-type", "hljs-class", "hljs-template-tag":
            return type
        case "hljs-variable", "hljs-params", "hljs-template-variable":
            return variable
        default:
            return nil
        }
    }
}
