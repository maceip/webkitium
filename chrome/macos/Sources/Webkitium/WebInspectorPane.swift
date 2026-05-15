import SwiftUI

/// Bottom-docked Web Inspector pane stub. Matches Safari's Inspector chrome: a top tab
/// row (Elements / Console / Network / Storage / Sources), a thin toolbar with filter
/// controls, then the pane body. Content is a static visual scaffold — this clone is for
/// chrome-level interop testing, not a real inspector.
struct WebInspectorPane: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var browserBinding = browser
        VStack(spacing: 0) {
            tabBar
            Divider()
            paneBody
        }
        .frame(height: 240)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private var tabBar: some View {
        @Bindable var browserBinding = browser
        return HStack(spacing: 0) {
            ForEach(BrowserViewModel.InspectorPane.allCases) { pane in
                InspectorTabButton(pane: pane,
                                    selected: pane == browser.inspectorPane) {
                    browser.inspectorPane = pane
                }
            }
            Spacer()
            Button { browser.showInspector = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Close Web Inspector")
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
    }

    @ViewBuilder
    private var paneBody: some View {
        switch browser.inspectorPane {
        case .elements: elements
        case .console:  console
        case .network:  network
        case .storage:  storage
        case .sources:  sources
        }
    }

    private var elements: some View {
        HStack(spacing: 0) {
            ScrollView { Text(htmlTree).font(.system(size: 11, design: .monospaced)).padding(8) }
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            ScrollView { Text(stylesText).font(.system(size: 11, design: .monospaced)).padding(8) }
                .frame(width: 240, alignment: .leading)
        }
    }

    private var console: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("> document.title").font(.system(size: 11, design: .monospaced))
                Text("\"\(browser.selectedTab?.title ?? "Apple")\"")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("> window.location.href").font(.system(size: 11, design: .monospaced))
                Text("\"https://www.apple.com/\"")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
    }

    private var network: some View {
        Table(of: NetworkRow.self) {
            TableColumn("Name") { Text($0.name).font(.system(size: 11)) }
            TableColumn("Type") { Text($0.kind).font(.system(size: 11)) }
            TableColumn("Status") { Text($0.status).font(.system(size: 11)) }
            TableColumn("Size") { Text($0.size).font(.system(size: 11)) }
            TableColumn("Time") { Text($0.time).font(.system(size: 11)) }
        } rows: {
            ForEach(NetworkRow.sample) { TableRow($0) }
        }
    }

    private var storage: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Cookies").font(.system(size: 11, weight: .semibold))
                Text("Local Storage").font(.system(size: 11))
                Text("Session Storage").font(.system(size: 11))
                Text("IndexedDB").font(.system(size: 11))
                Spacer()
            }
            .padding(8)
            .frame(width: 160, alignment: .leading)
            Divider()
            Text("Select a storage type.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sources: some View {
        Text("Sources").font(.system(size: 11))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.secondary)
    }

    private let htmlTree = """
    <html>
      <head>
        <title>Apple</title>
      </head>
      <body class="ac-globalnav-anchor">
        <nav id="ac-globalnav">…</nav>
        <main>
          <section class="hero">…</section>
        </main>
      </body>
    </html>
    """

    private let stylesText = """
    body {
        margin: 0;
        font-family: -apple-system, ...;
        color: #1d1d1f;
    }
    .hero {
        background: #fafafa;
        padding: 80px 0;
    }
    """
}

private struct InspectorTabButton: View {
    let pane: BrowserViewModel.InspectorPane
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: pane.symbol).font(.system(size: 10))
                Text(pane.rawValue).font(.system(size: 11, weight: selected ? .semibold : .regular))
            }
            .padding(.horizontal, 10).frame(height: 22)
            .foregroundStyle(selected ? .white : .primary)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? Color.accentColor :
                          (hovering ? Color.primary.opacity(0.08) : .clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct NetworkRow: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let status: String
    let size: String
    let time: String

    static let sample: [NetworkRow] = [
        .init(name: "index.html",       kind: "document",   status: "200", size: "14.2 KB", time: "32 ms"),
        .init(name: "app.css",          kind: "stylesheet", status: "200", size: "82.1 KB", time: "44 ms"),
        .init(name: "app.js",           kind: "script",     status: "200", size: "240 KB",  time: "118 ms"),
        .init(name: "hero@2x.jpg",      kind: "image",      status: "200", size: "1.2 MB",  time: "210 ms"),
        .init(name: "icon.svg",         kind: "image",      status: "200", size: "3.4 KB",  time: "8 ms"),
        .init(name: "telemetry.json",   kind: "xhr",        status: "204", size: "0 B",     time: "92 ms"),
    ]
}
