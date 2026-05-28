import AppKit
import SwiftUI

/// Renders a markdown document using `NSTextView` wrapped in `NSScrollView`.
/// NSTextView gives us native selection + ⌘C with both RTF and plain text on
/// the pasteboard for free. The custom subclass also adds an HTML
/// representation so paste into Gmail / Jira / Confluence picks that up.
struct DocumentWebView: NSViewRepresentable {
    let source: String
    let baseURL: URL?
    let isDarkMode: Bool
    let onNavigate: (URL) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(onNavigate: onNavigate) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = isDarkMode ? NSColor(red: 13/255, green: 17/255, blue: 23/255, alpha: 1)
                                            : NSColor.white

        let textView = RichCopyTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.usesFindBar = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 18)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.delegate = context.coordinator
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.heightTracksTextView = false
            container.lineFragmentPadding = 0
            container.containerSize = NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude)
        }

        scroll.documentView = textView
        render(into: textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        scroll.backgroundColor = isDarkMode ? NSColor(red: 13/255, green: 17/255, blue: 23/255, alpha: 1)
                                            : NSColor.white
        context.coordinator.onNavigate = onNavigate
        guard let textView = scroll.documentView as? RichCopyTextView else { return }
        // Keep the text container width in sync with the scroll view's visible content width
        // so paragraphs wrap to the available space.
        let availableWidth = max(200, scroll.contentSize.width - textView.textContainerInset.width * 2)
        textView.textContainer?.containerSize = NSSize(
            width: availableWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.setFrameSize(NSSize(width: scroll.contentSize.width, height: textView.frame.height))
        let hash = source.hashValue ^ (isDarkMode ? 1 : 0)
        if hash != context.coordinator.lastHash {
            context.coordinator.lastHash = hash
            render(into: textView)
        }
    }

    private func render(into textView: NSTextView) {
        let attr = MarkdownASTRenderer.render(source: source, isDarkMode: isDarkMode)
        textView.textStorage?.setAttributedString(attr)
        if let storage = textView.textStorage {
            MermaidAttachmentRegistry.shared.bind(storage)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 600, height: proposal.height ?? 400)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onNavigate: (URL) -> Bool
        var lastHash: Int = 0
        init(onNavigate: @escaping (URL) -> Bool) { self.onNavigate = onNavigate }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url: URL?
            if let l = link as? URL { url = l }
            else if let s = link as? String { url = URL(string: s) }
            else { url = nil }
            guard let url else { return false }
            if onNavigate(url) { return true }
            NSWorkspace.shared.open(url)
            return true
        }
    }
}

/// NSTextView subclass that, on copy, places three representations on the
/// pasteboard: plain text, RTF, and HTML. Gmail/Jira/Confluence prefer the
/// HTML; Apple Mail/TextEdit RTF/Pages prefer RTF. Plain text is the fallback.
final class RichCopyTextView: NSTextView {
    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        guard let storage = textStorage else { return super.writeSelection(to: pboard, types: types) }
        let range = selectedRange()
        guard range.length > 0 else { return super.writeSelection(to: pboard, types: types) }
        let snippet = storage.attributedSubstring(from: range)

        pboard.clearContents()
        // declare the types we provide
        pboard.declareTypes([.string, .rtf, .html], owner: nil)
        pboard.setString(snippet.string, forType: .string)

        let fullRange = NSRange(location: 0, length: snippet.length)
        if let rtf = try? snippet.data(from: fullRange,
                                       documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pboard.setData(rtf, forType: .rtf)
        }
        if let htmlData = try? snippet.data(from: fullRange,
                                             documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
           let htmlString = String(data: htmlData, encoding: .utf8) {
            pboard.setString(htmlString, forType: .html)
        }
        return true
    }
}
