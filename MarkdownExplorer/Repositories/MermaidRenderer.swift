import AppKit
import Foundation
import WebKit

/// Renders a mermaid diagram off-screen into an NSImage using a WKWebView that
/// is NOT inside a SwiftUI hierarchy (avoids the rendering issue we hit when
/// wrapping WKWebView via NSViewRepresentable).
@MainActor
final class MermaidRenderer {
    static let shared = MermaidRenderer()

    private static let template: String? = {
        guard let url = Bundle.main.url(forResource: "mermaid-host", withExtension: "html") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }()
    private static let mermaidJS: String? = {
        guard let url = Bundle.main.url(forResource: "mermaid.min", withExtension: "js") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }()

    private init() {}

    /// Renders the diagram and returns an `NSImage`, or `nil` on failure.
    func render(source: String, isDarkMode: Bool) async -> NSImage? {
        guard let template = Self.template, let mermaidJS = Self.mermaidJS else { return nil }
        let theme = isDarkMode ? "dark" : "default"
        let bg = isDarkMode ? "#161b22" : "#ffffff"
        let fg = isDarkMode ? "#e6edf3" : "#1f2328"
        let html = template
            .replacingOccurrences(of: "__THEME__", with: theme)
            .replacingOccurrences(of: "__MERMAID_THEME__", with: theme)
            .replacingOccurrences(of: "__BG__", with: bg)
            .replacingOccurrences(of: "__FG__", with: fg)
            .replacingOccurrences(of: "__SOURCE__", with: htmlEscape(source))
            .replacingOccurrences(of: "__MERMAID_JS__", with: mermaidJS)

        return await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
            let pipeline = Pipeline(html: html, continuation: continuation)
            pipeline.start()
        }
    }

    private func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}

/// Owns the WKWebView for the duration of a single render. Strong-refs itself
/// so it stays alive until snapshotting completes.
@MainActor
private final class Pipeline: NSObject, WKScriptMessageHandler {
    private let html: String
    private let continuation: CheckedContinuation<NSImage?, Never>
    private var webView: WKWebView?
    private var resolved = false
    private var selfRef: Pipeline?

    init(html: String, continuation: CheckedContinuation<NSImage?, Never>) {
        self.html = html
        self.continuation = continuation
    }

    func start() {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        userContent.add(self, name: "ready")
        config.userContentController = userContent

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 200), configuration: config)
        webView.setValue(true, forKey: "drawsBackground")
        self.webView = webView
        self.selfRef = self

        webView.loadHTMLString(html, baseURL: nil)

        // Safety timeout — never wait more than 8 seconds for a diagram render.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if !self.resolved { self.finish(with: nil) }
        }
    }

    nonisolated func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ready" else { return }
        let body = message.body as? [String: Any]
        let width = (body?["width"] as? NSNumber)?.doubleValue ?? 900
        let height = (body?["height"] as? NSNumber)?.doubleValue ?? 200
        Task { @MainActor in
            await self.snapshot(width: width, height: height)
        }
    }

    private func snapshot(width: Double, height: Double) async {
        guard let webView = self.webView else {
            finish(with: nil); return
        }
        let bounded = NSSize(width: max(300, min(width + 24, 1200)), height: max(60, min(height + 24, 1800)))
        webView.setFrameSize(bounded)

        let cfg = WKSnapshotConfiguration()
        cfg.rect = NSRect(origin: .zero, size: bounded)
        cfg.afterScreenUpdates = true

        await withCheckedContinuation { (cc: CheckedContinuation<Void, Never>) in
            webView.takeSnapshot(with: cfg) { [weak self] image, _ in
                Task { @MainActor [weak self] in
                    self?.finish(with: image)
                    cc.resume()
                }
            }
        }
    }

    private func finish(with image: NSImage?) {
        guard !resolved else { return }
        resolved = true
        webView = nil
        continuation.resume(returning: image)
        selfRef = nil
    }
}
