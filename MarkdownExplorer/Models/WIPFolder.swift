import Foundation

enum SidebarMode: String, CaseIterable, Hashable, Sendable {
    case tree
    case wip

    var label: String {
        switch self {
        case .tree: "Explore"
        case .wip: "In progress"
        }
    }
}

struct WIPFile: Identifiable, Hashable, Sendable {
    let node: FileNode
    let modified: Date

    var id: URL { node.url }
}

struct WIPFolder: Identifiable, Hashable, Sendable {
    let url: URL
    let projectURL: URL
    let projectName: String
    let parentPath: String
    let files: [WIPFile]
    let mostRecentMtime: Date

    var id: URL { url }
}

struct ProjectState: Identifiable, Sendable {
    let url: URL
    var lastKnownMaxMtime: Date
    var lastScannedAt: Date
    var folders: [WIPFolder]

    var id: URL { url }
}
