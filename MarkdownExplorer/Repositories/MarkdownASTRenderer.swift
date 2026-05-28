import AppKit
import Foundation
import Markdown

enum MarkdownASTRenderer {
    static func render(source: String, isDarkMode: Bool) -> NSAttributedString {
        let document = Document(parsing: source)
        let palette = Palette(isDarkMode: isDarkMode)
        var renderer = AttributedStringRenderer(palette: palette)
        renderer.visit(document)
        return renderer.finished
    }
}

// MARK: - Palette

struct Palette {
    let text: NSColor
    let muted: NSColor
    let link: NSColor
    let codeBg: NSColor
    let inlineCodeBg: NSColor
    let border: NSColor
    let headerBg: NSColor
    let isDarkMode: Bool

    init(isDarkMode: Bool) {
        self.isDarkMode = isDarkMode
        if isDarkMode {
            text = NSColor(red: 0.90, green: 0.93, blue: 0.95, alpha: 1)
            muted = NSColor(white: 0.55, alpha: 1)
            link = NSColor(red: 0.27, green: 0.58, blue: 0.97, alpha: 1)
            codeBg = NSColor(red: 0.09, green: 0.11, blue: 0.13, alpha: 1)
            inlineCodeBg = NSColor(red: 0.18, green: 0.21, blue: 0.25, alpha: 1)
            border = NSColor(red: 0.20, green: 0.23, blue: 0.27, alpha: 1)
            headerBg = NSColor(red: 0.13, green: 0.16, blue: 0.20, alpha: 1)
        } else {
            text = NSColor(red: 0.12, green: 0.14, blue: 0.16, alpha: 1)
            muted = NSColor(white: 0.45, alpha: 1)
            link = NSColor(red: 0.04, green: 0.41, blue: 0.85, alpha: 1)
            codeBg = NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
            inlineCodeBg = NSColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1)
            border = NSColor(red: 0.86, green: 0.88, blue: 0.90, alpha: 1)
            headerBg = NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
        }
    }
}

// MARK: - Renderer

private struct AttributedStringRenderer {
    let palette: Palette
    var output = NSMutableAttributedString()

    var finished: NSAttributedString { output }

    // MARK: - block dispatch

    mutating func visit(_ markup: Markup) {
        switch markup {
        case let node as Document:
            for child in node.children { visit(child) }
        case let node as Heading:
            renderHeading(node)
        case let node as Paragraph:
            renderParagraph(node)
        case let node as BlockQuote:
            renderBlockQuote(node)
        case let node as UnorderedList:
            renderList(node.listItems, ordered: false, level: 0)
        case let node as OrderedList:
            renderList(node.listItems, ordered: true, level: 0)
        case let node as CodeBlock:
            renderCodeBlock(node)
        case let node as ThematicBreak:
            _ = node
            renderThematicBreak()
        case let node as Table:
            renderTable(node)
        case let node as HTMLBlock:
            renderRawText(node.rawHTML)
        default:
            for child in markup.children { visit(child) }
        }
    }

    // MARK: - blocks

    private mutating func renderHeading(_ node: Heading) {
        let inline = renderInlines(node.inlineChildren, baseFont: headingFont(level: node.level), color: palette.text)
        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = node.level <= 2 ? 18 : 12
        para.paragraphSpacing = 8
        para.lineSpacing = 1
        let m = NSMutableAttributedString(attributedString: inline)
        m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
        // Bottom border for h1 / h2 via an underline rendered on a trailing whitespace newline run.
        output.append(m)
        if node.level <= 2 {
            let border = NSAttributedString(string: "\u{00A0}\n", attributes: [
                .font: NSFont.systemFont(ofSize: 1),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: palette.border,
                .foregroundColor: NSColor.clear
            ])
            output.append(border)
        }
        output.append(NSAttributedString(string: "\n"))
    }

    private mutating func renderParagraph(_ node: Paragraph) {
        let inline = renderInlines(node.inlineChildren, baseFont: bodyFont(), color: palette.text)
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 10
        para.lineSpacing = 3
        let m = NSMutableAttributedString(attributedString: inline)
        m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
        output.append(m)
        output.append(NSAttributedString(string: "\n"))
    }

    private mutating func renderBlockQuote(_ node: BlockQuote) {
        var inner = AttributedStringRenderer(palette: palette)
        for child in node.children { inner.visit(child) }
        let body = inner.finished
        let para = NSMutableParagraphStyle()
        para.headIndent = 20
        para.firstLineHeadIndent = 20
        para.paragraphSpacing = 10
        let m = NSMutableAttributedString(attributedString: body)
        m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
        m.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: m.length)) { value, range, _ in
            if value == nil || (value as? NSColor) == palette.text {
                m.addAttribute(.foregroundColor, value: palette.muted, range: range)
            }
        }
        output.append(m)
    }

    private mutating func renderList(_ items: some Sequence<ListItem>, ordered: Bool, level: Int) {
        var index = 1
        for item in items {
            let marker = ordered ? "\(index).\u{00A0}" : "•\u{00A0}"
            let para = NSMutableParagraphStyle()
            para.headIndent = CGFloat(20 + level * 20)
            para.firstLineHeadIndent = CGFloat(level * 20)
            para.paragraphSpacing = 4
            para.lineSpacing = 3

            // task list?
            var markerText = marker
            if let checkbox = item.checkbox {
                markerText = (checkbox == .checked ? "☑\u{00A0}" : "☐\u{00A0}")
            }

            let markerAttr = NSAttributedString(string: markerText, attributes: [
                .font: bodyFont(),
                .foregroundColor: palette.muted,
                .paragraphStyle: para
            ])

            // Render the item body recursively (handles nested lists, paragraphs, etc.)
            var inner = AttributedStringRenderer(palette: palette)
            for child in item.children { inner.visit(child) }
            var body = NSMutableAttributedString(attributedString: inner.finished)
            // Trim trailing newline so the marker stays on the same line as content
            while body.string.hasSuffix("\n\n") {
                body.deleteCharacters(in: NSRange(location: body.length - 1, length: 1))
            }
            // Apply our paragraph style to all paragraph runs that don't already have a deeper indent
            body.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: body.length)) { value, range, _ in
                if let style = value as? NSParagraphStyle {
                    let mut = NSMutableParagraphStyle()
                    mut.setParagraphStyle(style)
                    mut.headIndent = max(mut.headIndent, para.headIndent)
                    body.addAttribute(.paragraphStyle, value: mut, range: range)
                } else {
                    body.addAttribute(.paragraphStyle, value: para, range: range)
                }
            }

            output.append(markerAttr)
            output.append(body)
            index += 1
        }
        output.append(NSAttributedString(string: "\n"))
    }

    private mutating func renderCodeBlock(_ node: CodeBlock) {
        let lang = node.language ?? ""
        let code = node.code.trimmingCharacters(in: .newlines)

        if lang.lowercased() == "mermaid" {
            renderMermaid(source: code)
            return
        }

        let highlighted = SyntaxHighlighter.shared.highlight(code, language: lang, isDarkMode: palette.isDarkMode)
        let m = NSMutableAttributedString(attributedString: highlighted)
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 8
        para.paragraphSpacingBefore = 8
        para.headIndent = 12
        para.firstLineHeadIndent = 12
        para.tailIndent = -12
        para.lineSpacing = 2
        m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
        m.addAttribute(.backgroundColor, value: palette.codeBg, range: NSRange(location: 0, length: m.length))

        // Pad top and bottom so the background block has breathing room
        let topPad = NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 6),
            .backgroundColor: palette.codeBg,
            .paragraphStyle: para
        ])
        output.append(topPad)
        output.append(m)
        output.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 6),
            .backgroundColor: palette.codeBg,
            .paragraphStyle: para
        ]))
        output.append(NSAttributedString(string: "\n"))
    }

    private mutating func renderMermaid(source: String) {
        let attachment = NSTextAttachment()
        let cell = MermaidAttachmentCell(text: "Diagram rendering…", palette: palette)
        attachment.attachmentCell = cell
        let str = NSMutableAttributedString(attachment: attachment)
        let location = output.length
        output.append(str)
        output.append(NSAttributedString(string: "\n\n"))
        // Schedule async swap (capture only value types)
        let isDarkMode = palette.isDarkMode
        Task { @MainActor in
            if let image = await MermaidRenderer.shared.render(source: source, isDarkMode: isDarkMode) {
                MermaidAttachmentRegistry.shared.fulfill(location: location, image: image)
            } else {
                MermaidAttachmentRegistry.shared.fulfill(location: location, error: "Mermaid render failed")
            }
        }
    }

    private mutating func renderThematicBreak() {
        let line = NSAttributedString(string: "\u{00A0}\n", attributes: [
            .font: NSFont.systemFont(ofSize: 1),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: palette.border,
            .foregroundColor: NSColor.clear
        ])
        output.append(line)
        output.append(NSAttributedString(string: "\n"))
    }

    private mutating func renderTable(_ node: Table) {
        let table = NSTextTable()
        table.numberOfColumns = node.maxColumnCount
        table.layoutAlgorithm = .automaticLayoutAlgorithm
        table.collapsesBorders = true

        appendRow(node.head.cells, table: table, isHeader: true)
        for row in node.body.rows {
            appendRow(row.cells, table: table, isHeader: false)
        }
        output.append(NSAttributedString(string: "\n"))
    }

    private mutating func appendRow(_ cells: some Sequence<Table.Cell>, table: NSTextTable, isHeader: Bool) {
        for cell in cells {
            let block = NSTextTableBlock(table: table, startingRow: -1, rowSpan: 1, startingColumn: -1, columnSpan: 1)
            block.setWidth(8, type: .absoluteValueType, for: .padding)
            block.setWidth(1, type: .absoluteValueType, for: .border)
            block.setBorderColor(palette.border)
            if isHeader {
                block.backgroundColor = palette.headerBg
            }

            let para = NSMutableParagraphStyle()
            para.textBlocks = [block]
            para.paragraphSpacing = 0

            let baseFont = isHeader
                ? NSFont.systemFont(ofSize: 14, weight: .semibold)
                : bodyFont()
            let inline = renderInlines(cell.inlineChildren, baseFont: baseFont, color: palette.text)
            let m = NSMutableAttributedString(attributedString: inline)
            m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
            m.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: para]))
            output.append(m)
        }
    }

    private mutating func renderRawText(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
            .foregroundColor: palette.muted
        ]
        output.append(NSAttributedString(string: text + "\n", attributes: attrs))
    }

    // MARK: - inline

    private func renderInlines(_ inlines: some Sequence<InlineMarkup>, baseFont: NSFont, color: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for inline in inlines {
            result.append(renderInline(inline, baseFont: baseFont, color: color))
        }
        return result
    }

    private func renderInline(_ inline: Markup, baseFont: NSFont, color: NSColor) -> NSAttributedString {
        switch inline {
        case let node as Text:
            return NSAttributedString(string: node.string, attributes: [
                .font: baseFont,
                .foregroundColor: color
            ])
        case let node as Strong:
            let bold = applyBold(to: baseFont)
            return renderInlines(node.inlineChildren, baseFont: bold, color: color)
        case let node as Emphasis:
            let italic = applyItalic(to: baseFont)
            return renderInlines(node.inlineChildren, baseFont: italic, color: color)
        case let node as Strikethrough:
            let inner = renderInlines(node.inlineChildren, baseFont: baseFont, color: color)
            let m = NSMutableAttributedString(attributedString: inner)
            m.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: m.length))
            return m
        case let node as Link:
            let inner = renderInlines(node.inlineChildren, baseFont: baseFont, color: palette.link)
            let m = NSMutableAttributedString(attributedString: inner)
            if let destination = node.destination, let url = URL(string: destination) {
                m.addAttribute(.link, value: url, range: NSRange(location: 0, length: m.length))
            }
            m.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: m.length))
            return m
        case let node as InlineCode:
            let monoSize = baseFont.pointSize * 0.92
            return NSAttributedString(string: node.code, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: monoSize, weight: .regular),
                .foregroundColor: color,
                .backgroundColor: palette.inlineCodeBg
            ])
        case let node as Image:
            let alt = node.plainText
            return NSAttributedString(string: "[image: \(alt)]", attributes: [
                .font: baseFont,
                .foregroundColor: palette.muted
            ])
        case _ as LineBreak:
            return NSAttributedString(string: "\n", attributes: [.font: baseFont])
        case _ as SoftBreak:
            return NSAttributedString(string: " ", attributes: [.font: baseFont])
        case let node as InlineHTML:
            return NSAttributedString(string: node.rawHTML, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.92, weight: .regular),
                .foregroundColor: palette.muted
            ])
        default:
            let result = NSMutableAttributedString()
            for child in inline.children {
                result.append(renderInline(child, baseFont: baseFont, color: color))
            }
            return result
        }
    }

    // MARK: - font helpers

    private func bodyFont() -> NSFont { NSFont.systemFont(ofSize: 14) }

    private func headingFont(level: Int) -> NSFont {
        switch level {
        case 1: return NSFont.systemFont(ofSize: 26, weight: .bold)
        case 2: return NSFont.systemFont(ofSize: 22, weight: .semibold)
        case 3: return NSFont.systemFont(ofSize: 18, weight: .semibold)
        case 4: return NSFont.systemFont(ofSize: 16, weight: .semibold)
        case 5: return NSFont.systemFont(ofSize: 14, weight: .semibold)
        default: return NSFont.systemFont(ofSize: 13, weight: .semibold)
        }
    }

    private func applyBold(to font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
    }

    private func applyItalic(to font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
}

// MARK: - Mermaid attachment cell

final class MermaidAttachmentCell: NSTextAttachmentCell {
    private var text: String
    private let palette: Palette
    private var renderedImage: NSImage?
    private let baseHeight: CGFloat = 60

    init(text: String, palette: Palette) {
        self.text = text
        self.palette = palette
        super.init(textCell: text)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func install(image: NSImage) {
        self.renderedImage = image
    }

    func update(text: String) {
        self.text = text
    }

    override func cellSize() -> NSSize {
        if let renderedImage { return renderedImage.size }
        return NSSize(width: 600, height: baseHeight)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        if let renderedImage {
            renderedImage.draw(in: cellFrame, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            // Placeholder: rounded rect with text
            let path = NSBezierPath(roundedRect: cellFrame.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6)
            palette.codeBg.setFill()
            path.fill()
            palette.border.setStroke()
            path.stroke()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: palette.muted
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let size = str.size()
            let p = NSPoint(
                x: cellFrame.midX - size.width / 2,
                y: cellFrame.midY - size.height / 2
            )
            str.draw(at: p)
        }
    }
}

@MainActor
final class MermaidAttachmentRegistry {
    static let shared = MermaidAttachmentRegistry()
    private init() {}

    private weak var currentTextStorage: NSTextStorage?
    private var locations: [Int] = []

    func bind(_ textStorage: NSTextStorage) {
        currentTextStorage = textStorage
        locations.removeAll()
    }

    func fulfill(location: Int, image: NSImage) {
        guard let storage = currentTextStorage else { return }
        guard location < storage.length else { return }
        let range = NSRange(location: location, length: 1)
        storage.enumerateAttribute(.attachment, in: range) { value, _, _ in
            if let attachment = value as? NSTextAttachment,
               let cell = attachment.attachmentCell as? MermaidAttachmentCell {
                cell.install(image: image)
            }
        }
        storage.edited([.editedAttributes], range: range, changeInLength: 0)
    }

    func fulfill(location: Int, error: String) {
        guard let storage = currentTextStorage else { return }
        guard location < storage.length else { return }
        let range = NSRange(location: location, length: 1)
        storage.enumerateAttribute(.attachment, in: range) { value, _, _ in
            if let attachment = value as? NSTextAttachment,
               let cell = attachment.attachmentCell as? MermaidAttachmentCell {
                cell.update(text: error)
            }
        }
        storage.edited([.editedAttributes], range: range, changeInLength: 0)
    }
}
