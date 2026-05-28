# Markdown Explorer

A native macOS SwiftUI app for browsing and reading folders of Markdown files. Tree on the left, rendered preview on the right, plus an "In progress" sidebar that surfaces the projects you actually touched recently.

<!-- screenshot here -->

## Install

Grab the latest `.dmg` from the [Releases](https://github.com/mobando-gravie/markdown-explorer/releases) page, open it, and drag **Markdown Explorer** to your **Applications** folder.

**First launch** — because this build isn't notarized (no paid Apple Developer ID yet), macOS will refuse to open it with a "cannot check for malicious software" warning. To bypass once:

- In Finder, **right-click** (or Control-click) the app → **Open** → click **Open** in the dialog.
- macOS remembers the choice; subsequent launches are normal.

Alternatively, after the first refused launch, **System Settings → Privacy & Security → Open Anyway** works too.

## Features

- **Two sidebar modes**
  - **Explore** — recursive lazy-loaded file tree, like Finder's column view.
  - **In progress** — historical project list; folders sorted by most-recent `.md` edit, with smart per-project hot/cold polling so the sidebar stays fresh without thrashing the filesystem.
- **Syntax-highlighted code blocks** — ~38 languages via bundled highlight.js running in `JavaScriptCore`. Light/dark themes auto-follow the system.
- **Copy button on code blocks** — hover to reveal; one click puts the raw source on your clipboard.
- **Markdown link navigation** — internal `[link](./other.md)` references load the target file; external links open in your browser.
- **Quick Open** (⌘⇧O) — fuzzy-search any `.md` file in the workspace.
- **Reveal in Finder** — right-click any file row in the sidebar.
- **Recent folders** — `File → Open Recent` keeps the last 5 workspaces.
- **GFM rendering** — headings, lists, task lists, blockquotes, code, tables, images, links — via [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui).
- **Mermaid diagrams** — ` ```mermaid ` fenced blocks render as live SVG via a bundled `mermaid.min.js` running in a `WKWebView` (no network at runtime).
- **Sandboxed, with persisted folder access** — uses security-scoped bookmarks so the last folder reopens automatically across launches.
- **Auto-discovery of project roots** — the In-progress mode walks each folder's ancestors looking for markers (`.git`, `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Package.swift`, `Gemfile`, `composer.json`, `mix.exs`, `Makefile`, `CMakeLists.txt`, `pom.xml`, `build.gradle[.kts]`, `.hg`, `.svn`, `.idea`, `.vscode`, `node_modules`, `Pods`, `Carthage`, `vendor`, `.venv`, `venv`, `.gradle`, `*.xcodeproj/`) to label rows as `project › parent`.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon (arm64)
- For building from source: Xcode 26+, [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build from source

If you'd rather build it yourself instead of using the release DMG:

### Quickstart

```sh
brew install xcodegen
xcodegen generate
open MarkdownExplorer.xcodeproj
# then ⌘R in Xcode
```

Or build from the command line:

```sh
xcodegen generate
xcodebuild -project MarkdownExplorer.xcodeproj \
           -scheme MarkdownExplorer \
           -configuration Debug \
           -destination 'platform=macOS' \
           build
open ~/Library/Developer/Xcode/DerivedData/MarkdownExplorer-*/Build/Products/Debug/MarkdownExplorer.app
```

### Cutting a release

To produce a distributable `.dmg` and publish it as a GitHub release:

```sh
scripts/release.sh 0.1.0   # version, no `v` prefix
```

The script builds Release config, packages the `.app` into a DMG via `hdiutil`, tags `v0.1.0`, pushes the tag, and calls `gh release create` with notes from `docs/releases/v0.1.0.md`. It refuses to run if the git tree isn't clean, the tag already exists, or the notes file is missing.

## Usage

1. Press **⌘O** (or click the Open Folder toolbar button) and pick any folder containing `.md` files.
2. The sidebar starts in **In progress** mode — your most-recently edited folders are at the top. Switch to **Explore** for a full recursive tree.
3. Click any `.md` file to render it on the right.
4. Click the **Refresh** button in the toolbar (or the small refresh in the sidebar header) to force a full re-scan.
5. The folder picker is remembered across launches.

## Sidebar modes

### Explore

A lazy-loaded recursive tree built from `DisclosureGroup`. Folders expand on click; children load on first expansion and stay cached. Hidden files and packages are skipped.

### In progress

A historical, per-project view of where the work is happening.

- **Bootstrap** — on first entry (and on Refresh, and hourly after that), the app walks the entire workspace once to discover all projects and the `.md` files inside them.
- **Hot polling** — projects with any `.md` change inside the last **30 minutes** get re-scanned every **1 minute**.
- **Cold polling** — projects idle for ≥30 minutes get re-scanned at most every **30 minutes**, so the app doesn't waste cycles on dormant work.
- **Display** — every project with `.md` files appears, regardless of age. The list only empties when the workspace truly has no Markdown. Each row shows the project › direct-parent breadcrumb and up to the 10 most-recent files inline.
- **Persistence** — state is kept across Explore↔In-progress toggles and only cleared when you open a different workspace.

## Architecture

Flat layering: views are thin, a single `@Observable` store orchestrates, two repositories own all IO.

```
ContentView (NavigationSplitView)
 ├─ SidebarView ─ switches by store.sidebarMode
 │   ├─ FileTreeView                     ← Explore mode
 │   └─ WIPFoldersView ─ WIPFolderRow    ← In progress mode
 └─ DetailView ─ EmptyStateView | MarkdownDocumentView
                                          └─ MermaidWebView (WKWebView)

           ▲ reads / observes
           │
   WorkspaceStore (@Observable, @MainActor)
   ┌──────────────────────────────┐
   │ rootURL, selectedURL,        │
   │ expanded, childrenCache,     │
   │ sidebarMode, projectStates,  │
   │ wipFolders, lastBootstrapAt  │
   └──────────────────────────────┘
           │
           ▼ calls
   FileSystemRepository    BookmarkRepository
   ├ presentOpenPanel      ├ save(URL)
   ├ list(dir)             ├ restore() → URL?
   ├ read(file)            └ clear()
   ├ enumerateMarkdown(_)    (security-scoped bookmarks)
   └ isProjectRoot(_)
```

Dependency direction is one-way: View → Store → Repository. Views never talk to repositories. Repositories never know about SwiftUI.

## Project structure

```
markdown-explorer/
├── MarkdownExplorer/
│   ├── App/                       @main entry, scene wiring
│   ├── Models/                    FileNode, SidebarMode, WIPFolder, ProjectState
│   ├── Repositories/              FileSystemRepository, BookmarkRepository
│   ├── Stores/                    WorkspaceStore (the single orchestrator)
│   ├── Views/
│   │   ├── ContentView.swift      NavigationSplitView shell + toolbar
│   │   ├── Sidebar/               SidebarView, FileTreeView, FileNodeRow,
│   │   │                          WIPFoldersView, WIPFolderRow
│   │   └── Detail/                DetailView, EmptyStateView,
│   │                              MarkdownDocumentView, MermaidWebView
│   ├── Resources/                 mermaid.min.js, mermaid-host.html,
│   │                              AppIcon-source.svg
│   ├── Assets.xcassets/           AppIcon
│   ├── Info.plist
│   └── MarkdownExplorer.entitlements
├── project.yml                    xcodegen spec (single source of truth)
├── README.md
├── LICENSE
└── .gitignore
```

`MarkdownExplorer.xcodeproj/` is intentionally gitignored — it's regenerated from `project.yml` by `xcodegen generate`. Re-run that whenever you add, rename, or remove a source file.

## Acknowledgements

- **[Tabler Icons](https://tabler.io/icons)** (MIT) — `folder-search` is the basis for the app icon.
- **[swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui)** (MIT) — GFM rendering engine.
- **[Mermaid](https://mermaid.js.org/)** (MIT) — diagram rendering inside fenced code blocks.
- **[highlight.js](https://highlightjs.org/)** (BSD-3-Clause) — syntax highlighting (~38 languages).
- **[xcodegen](https://github.com/yonaskolb/XcodeGen)** (MIT) — project file generation.
- Apple SF Symbols — toolbar and sidebar iconography.

## License

[MIT](LICENSE) © 2026 Miguel Obando
