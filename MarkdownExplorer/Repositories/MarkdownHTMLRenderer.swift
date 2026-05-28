import Foundation

struct DocumentRenderRequest {
    let source: String
    let baseURL: URL?
    let isDarkMode: Bool
}

enum MarkdownHTMLRenderer {
    static func render(_ req: DocumentRenderRequest) -> String? {
        guard let template = Bundle.main.string(forResource: "document-host", ofType: "html"),
              let githubCSS = Bundle.main.string(forResource: "github-markdown", ofType: "css"),
              let markdownIt = Bundle.main.string(forResource: "markdown-it.min", ofType: "js"),
              let taskLists = Bundle.main.string(forResource: "markdown-it-task-lists.min", ofType: "js"),
              let highlightJS = Bundle.main.string(forResource: "highlight.min", ofType: "js"),
              let mermaidJS = Bundle.main.string(forResource: "mermaid.min", ofType: "js")
        else { return nil }

        let theme = req.isDarkMode ? "dark" : "light"
        let hljsThemeName = req.isDarkMode ? "highlight-github-dark" : "highlight-github-light"
        let hljsThemeCSS = Bundle.main.string(forResource: hljsThemeName, ofType: "css") ?? ""

        let sourceB64 = req.source.data(using: .utf8)?.base64EncodedString() ?? ""

        return template
            .replacingOccurrences(of: "__THEME__", with: theme)
            .replacingOccurrences(of: "__GITHUB_MARKDOWN_CSS__", with: githubCSS)
            .replacingOccurrences(of: "__HLJS_THEME_CSS__", with: hljsThemeCSS)
            .replacingOccurrences(of: "__MARKDOWN_IT_JS__", with: markdownIt)
            .replacingOccurrences(of: "__TASKLISTS_JS__", with: taskLists)
            .replacingOccurrences(of: "__HIGHLIGHT_JS__", with: highlightJS)
            .replacingOccurrences(of: "__MERMAID_JS__", with: mermaidJS)
            .replacingOccurrences(of: "__SOURCE_B64__", with: sourceB64)
    }
}

private extension Bundle {
    func string(forResource name: String, ofType ext: String) -> String? {
        guard let url = url(forResource: name, withExtension: ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
