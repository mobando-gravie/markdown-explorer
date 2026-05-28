import Foundation

struct FileNode: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isMarkdown: Bool

    var id: URL { url }
}

extension FileNode {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    static func from(url: URL, resourceValues: URLResourceValues) -> FileNode {
        let isDir = resourceValues.isDirectory ?? false
        let ext = url.pathExtension.lowercased()
        return FileNode(
            url: url,
            name: resourceValues.localizedName ?? url.lastPathComponent,
            isDirectory: isDir,
            isMarkdown: !isDir && markdownExtensions.contains(ext)
        )
    }
}
