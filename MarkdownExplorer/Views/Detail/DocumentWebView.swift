import AppKit
import SwiftUI
import WebKit

struct DocumentWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    let onNavigate: (URL) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigate: onNavigate)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = false
        loadIfNeeded(into: webView, context: context)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onNavigate = onNavigate
        loadIfNeeded(into: webView, context: context)
    }

    private func loadIfNeeded(into webView: WKWebView, context: Context) {
        let signature = html.hashValue
        guard signature != context.coordinator.lastLoadedSignature else { return }
        context.coordinator.lastLoadedSignature = signature
        context.coordinator.didLoadInitial = false
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onNavigate: (URL) -> Bool
        var lastLoadedSignature: Int = 0
        var didLoadInitial: Bool = false

        init(onNavigate: @escaping (URL) -> Bool) {
            self.onNavigate = onNavigate
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Initial loadHTMLString gets navigationType .other with about:blank
            if !didLoadInitial, navigationAction.navigationType == .other {
                didLoadInitial = true
                decisionHandler(.allow)
                return
            }

            // In-page anchors: allow
            if navigationAction.navigationType == .linkActivated, url.fragment != nil,
               url.path.isEmpty || url.path == webView.url?.path {
                decisionHandler(.allow)
                return
            }

            if navigationAction.navigationType == .linkActivated {
                if onNavigate(url) {
                    decisionHandler(.cancel)
                    return
                }
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}
