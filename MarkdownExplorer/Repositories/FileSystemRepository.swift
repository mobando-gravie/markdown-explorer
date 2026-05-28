import AppKit
import Foundation

struct MarkdownEntry: Sendable {
    let url: URL
    let modified: Date
}

protocol FileSystemRepository {
    @MainActor func presentOpenPanel() async -> URL?
    func list(_ directory: URL) throws -> [FileNode]
    func read(_ file: URL) throws -> String
    func enumerateMarkdown(_ root: URL) throws -> [MarkdownEntry]
    func isProjectRoot(_ directory: URL) -> Bool
}

struct DefaultFileSystemRepository: FileSystemRepository {

    @MainActor
    func presentOpenPanel() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder of Markdown files"
        panel.prompt = "Open"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    func list(_ directory: URL) throws -> [FileNode] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .localizedNameKey, .isHiddenKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        let nodes: [FileNode] = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let node = FileNode.from(url: url, resourceValues: values)
            return (node.isDirectory || node.isMarkdown) ? node : nil
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func read(_ file: URL) throws -> String {
        try String(contentsOf: file, encoding: .utf8)
    }

    func enumerateMarkdown(_ root: URL) throws -> [MarkdownEntry] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var entries: [MarkdownEntry] = []
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { continue }

            let ext = fileURL.pathExtension.lowercased()
            guard FileNode.markdownExtensions.contains(ext) else { continue }

            entries.append(MarkdownEntry(url: fileURL, modified: modified))
        }
        return entries
    }

    func isProjectRoot(_ directory: URL) -> Bool {
        for marker in Self.fileMarkers {
            let path = directory.appending(path: marker).path(percentEncoded: false)
            if FileManager.default.fileExists(atPath: path) { return true }
        }
        for marker in Self.directoryMarkers {
            let path = directory.appending(path: marker).path(percentEncoded: false)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return true
            }
        }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)) {
            if contents.contains(where: { $0.hasSuffix(".xcodeproj") }) { return true }
        }
        return false
    }

    private static let fileMarkers: [String] = [
        "package.json", "Cargo.toml", "pyproject.toml", "go.mod", "Package.swift",
        "pom.xml", "build.gradle", "build.gradle.kts",
        "Gemfile", "composer.json", "mix.exs",
        "Makefile", "CMakeLists.txt"
    ]

    private static let directoryMarkers: [String] = [
        ".git", ".hg", ".svn",
        ".idea", ".vscode",
        "node_modules", "Pods", "Carthage", "vendor",
        ".venv", "venv", ".gradle"
    ]
}
