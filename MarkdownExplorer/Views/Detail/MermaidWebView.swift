import AppKit
import SwiftUI
import WebKit

struct MermaidWebView: View {
    let source: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var measuredHeight: CGFloat = 80

    var body: some View {
        MermaidWebViewRepresentable(
            source: source,
            colorScheme: colorScheme,
            measuredHeight: $measuredHeight
        )
        .frame(height: measuredHeight)
    }
}

private struct MermaidWebViewRepresentable: NSViewRepresentable {
    let source: String
    let colorScheme: ColorScheme
    @Binding var measuredHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(measuredHeight: $measuredHeight)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "height")
        config.userContentController = userContent

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        loadHTML(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadHTML(into: webView)
    }

    private func loadHTML(into webView: WKWebView) {
        guard let html = MermaidHTMLBuilder.html(source: source, colorScheme: colorScheme) else {
            return
        }
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var measuredHeight: CGFloat

        init(measuredHeight: Binding<CGFloat>) {
            self._measuredHeight = measuredHeight
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "height" else { return }
            let value: CGFloat
            if let number = message.body as? NSNumber {
                value = CGFloat(truncating: number)
            } else if let double = message.body as? Double {
                value = CGFloat(double)
            } else {
                return
            }
            let bounded = max(40, min(value + 24, 2400))
            Task { @MainActor [bounded] in
                self.measuredHeight = bounded
            }
        }
    }
}

enum MermaidHTMLBuilder {
    private static let mermaidJS: String? = {
        guard let url = Bundle.main.url(forResource: "mermaid.min", withExtension: "js") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }()

    private static let template: String? = {
        guard let url = Bundle.main.url(forResource: "mermaid-host", withExtension: "html") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }()

    static func html(source: String, colorScheme: ColorScheme) -> String? {
        guard let template, let mermaidJS else { return nil }
        let theme = colorScheme == .dark ? "dark" : "default"
        let textColor = colorScheme == .dark ? "#e6e6e6" : "#1a1a1a"
        return template
            .replacingOccurrences(of: "__TEXT_COLOR__", with: textColor)
            .replacingOccurrences(of: "__THEME__", with: theme)
            .replacingOccurrences(of: "__SOURCE__", with: htmlEscape(source))
            .replacingOccurrences(of: "__MERMAID_JS__", with: mermaidJS)
    }

    private static func htmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
