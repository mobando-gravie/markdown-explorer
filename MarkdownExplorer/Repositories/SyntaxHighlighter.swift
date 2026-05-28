import AppKit
import JavaScriptCore
import SwiftUI

@MainActor
final class HighlightEngine {
    static let shared = HighlightEngine()

    private var context: JSContext?
    private var loaded = false

    private init() {}

    func highlight(_ code: String, language: String?, colorScheme: ColorScheme) -> AttributedString {
        ensureLoaded()
        guard let context else { return plain(code) }

        let escaped = JSValue(object: code, in: context).toString() ?? code
        _ = escaped
        context.setObject(code, forKeyedSubscript: "__src" as NSString)
        context.setObject(language as Any, forKeyedSubscript: "__lang" as NSString)

        let script: String
        if let language, !language.isEmpty, !language.lowercased().hasPrefix("mermaid") {
            script = """
            (function() {
              try {
                var langs = hljs.listLanguages();
                if (langs.indexOf(__lang) >= 0) {
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

        guard let html = context.evaluateScript(script)?.toString(), html != "undefined", !html.isEmpty else {
            return plain(code)
        }

        return parse(html, colorScheme: colorScheme) ?? plain(code)
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

    private func plain(_ code: String) -> AttributedString {
        var attr = AttributedString(code)
        attr.font = .system(.callout, design: .monospaced)
        return attr
    }

    private func parse(_ html: String, colorScheme: ColorScheme) -> AttributedString? {
        let palette = colorScheme == .dark ? Palette.dark : Palette.light
        var result = AttributedString()
        var stack: [Color] = []
        var i = html.startIndex
        var buf = ""

        func flush() {
            guard !buf.isEmpty else { return }
            let unescaped = HighlightEngine.unescape(buf)
            var run = AttributedString(unescaped)
            run.font = .system(.callout, design: .monospaced)
            if let color = stack.last {
                run.foregroundColor = color
            }
            result.append(run)
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
                    let cls = HighlightEngine.classAttribute(of: tag)
                    let color = palette.color(forHLJSClass: cls)
                    stack.append(color ?? stack.last ?? palette.defaultText)
                }
                continue
            }
            buf.append(ch)
            i = html.index(after: i)
        }
        flush()

        if result.runs.isEmpty { return nil }
        return result
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

private struct Palette {
    let defaultText: Color
    let keyword: Color
    let string: Color
    let number: Color
    let comment: Color
    let title: Color
    let builtin: Color
    let attr: Color
    let tag: Color
    let meta: Color
    let type: Color
    let variable: Color

    func color(forHLJSClass cls: String) -> Color? {
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
        case "hljs-meta", "hljs-meta-string", "hljs-deletion":
            return meta
        case "hljs-type", "hljs-class", "hljs-template-tag":
            return type
        case "hljs-variable", "hljs-params", "hljs-template-variable":
            return variable
        default:
            return nil
        }
    }

    static let dark = Palette(
        defaultText: Color(white: 0.90),
        keyword: Color(red: 0.78, green: 0.55, blue: 0.90),
        string:  Color(red: 0.60, green: 0.85, blue: 0.55),
        number:  Color(red: 0.95, green: 0.65, blue: 0.40),
        comment: Color(white: 0.50),
        title:   Color(red: 0.40, green: 0.75, blue: 0.95),
        builtin: Color(red: 0.40, green: 0.85, blue: 0.85),
        attr:    Color(red: 0.95, green: 0.78, blue: 0.40),
        tag:     Color(red: 0.95, green: 0.55, blue: 0.55),
        meta:    Color(white: 0.55),
        type:    Color(red: 0.50, green: 0.80, blue: 0.95),
        variable: Color(red: 0.90, green: 0.70, blue: 0.85)
    )

    static let light = Palette(
        defaultText: Color(white: 0.10),
        keyword: Color(red: 0.55, green: 0.20, blue: 0.65),
        string:  Color(red: 0.20, green: 0.55, blue: 0.20),
        number:  Color(red: 0.75, green: 0.35, blue: 0.10),
        comment: Color(white: 0.45),
        title:   Color(red: 0.15, green: 0.40, blue: 0.75),
        builtin: Color(red: 0.10, green: 0.55, blue: 0.55),
        attr:    Color(red: 0.65, green: 0.45, blue: 0.10),
        tag:     Color(red: 0.70, green: 0.20, blue: 0.20),
        meta:    Color(white: 0.40),
        type:    Color(red: 0.10, green: 0.45, blue: 0.70),
        variable: Color(red: 0.55, green: 0.35, blue: 0.55)
    )
}
