import AppKit
import Combine
import KiprCore
import SwiftUI

struct PickerEntry {
    let item: PickerItem
    let url: URL?
    let command: String?
    let children: [PickerEntry]?
    let isWallpaper: Bool
    let window: WindowOperation?
}

@MainActor
final class PickerModel: ObservableObject {
    @Published private(set) var screens: [[PickerEntry]] = []
    @Published private(set) var query = ""
    @Published var selection = 0

    var filteredEntries: [PickerEntry] {
        let items = screens.last ?? []
        let titles = Set(PickerLogic.filtered(items.map(\.item), query: query).map(\.title))
        return items.filter { titles.contains($0.item.title) }
    }

    func configure(with config: KiprConfig) {
        screens = [Self.sorted(config.actions.map { makeEntry(name: $0.key, action: $0.value) })]
    }

    private func makeEntry(name: String, action: KiprConfig.Action) -> PickerEntry {
        PickerEntry(
            item: PickerItem(title: name, shortcut: action.shortcut),
            url: action.type == "application" ? URL(fileURLWithPath: action.path ?? "") : nil,
            command: action.command,
            children: action.items.map { Self.sorted($0.map { makeEntry(name: $0.key, action: $0.value) }) },
            isWallpaper: action.type == "wallpaper",
            window: action.type == "window" ? action.operation.flatMap(WindowOperation.init) : nil
        )
    }

    /// Apps with shortcuts first, then custom actions, then everything else; by title within each group.
    private static func sorted(_ entries: [PickerEntry]) -> [PickerEntry] {
        func group(_ e: PickerEntry) -> Int {
            if e.url != nil { return e.item.shortcut != nil ? 0 : 2 }
            return e.command != nil || e.children != nil || e.isWallpaper || e.window != nil ? 1 : 2
        }
        return entries.sorted {
            (group($0), $0.item.title.lowercased()) < (group($1), $1.item.title.lowercased())
        }
    }

    func goBack() -> Bool {
        guard screens.count > 1 else { return false }
        screens.removeLast()
        setQuery("")
        return true
    }

    func push(_ children: [PickerEntry]) {
        screens.append(children)
        setQuery("")
    }

    func reset() {
        screens = Array(screens.prefix(1))
        setQuery("")
    }

    func setQuery(_ value: String) {
        query = value
        selection = 0
    }

    func move(_ offset: Int) {
        selection = PickerLogic.moveSelection(current: selection, offset: offset, count: filteredEntries.count)
    }

    enum Selection {
        case application(URL)
        case command(String)
        case submenu([PickerEntry])
        case wallpaper
        case window(WindowOperation)
        case none
    }

    func select(_ index: Int? = nil) -> Selection {
        let entries = filteredEntries
        guard entries.indices.contains(index ?? selection) else { return .none }
        selection = index ?? selection
        let entry = entries[selection]
        if entry.isWallpaper { return .wallpaper }
        if let url = entry.url { return .application(url) }
        if let children = entry.children { return .submenu(children) }
        if let window = entry.window { return .window(window) }
        if let command = entry.command { return .command(command) }
        return .none
    }
}

struct PickerView: View {
    @ObservedObject var model: PickerModel
    let onActivate: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.filteredEntries.enumerated()), id: \.offset) { index, entry in
                        let selected = index == model.selection
                        HStack {
                            Text(entry.item.title).font(.system(size: 19))
                            Spacer()
                            if let shortcut = entry.item.shortcut {
                                Text(shortcut)
                                    .font(.system(size: 15, design: .monospaced))
                                    .foregroundStyle(selected ? Color.white.opacity(0.8) : .secondary)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(selected ? Color.pink : .clear)
                        .foregroundStyle(selected ? Color.white : .primary)
                        .contentShape(Rectangle())
                        .onTapGesture { onActivate(index) }
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selection) { _, selection in
                proxy.scrollTo(selection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

final class PickerContentView: NSView, NSSearchFieldDelegate {
    private let model: PickerModel
    private let searchField = NSSearchField()
    private let resultsView: NSHostingView<PickerView>
    private var queryObserver: AnyCancellable?

    init(model: PickerModel, onActivate: @escaping (Int) -> Void) {
        self.model = model
        self.resultsView = NSHostingView(rootView: PickerView(model: model, onActivate: onActivate))
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        let background = NSVisualEffectView()
        background.material = .headerView
        background.blendingMode = .behindWindow
        background.state = .active
        background.frame = bounds
        background.autoresizingMask = [.width, .height]
        addSubview(background)
        searchField.font = .systemFont(ofSize: 26)
        searchField.textColor = .labelColor
        searchField.isBordered = false
        searchField.bezelStyle = .roundedBezel
        searchField.placeholderString = ""
        searchField.focusRingType = .none
        searchField.drawsBackground = false
        searchField.delegate = self
        searchField.stringValue = model.query
        queryObserver = model.$query.sink { [searchField] in
            if searchField.stringValue != $0 { searchField.stringValue = $0 }
        }
        addSubview(searchField)
        addSubview(resultsView)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        resultsView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 38),
            resultsView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 2),
            resultsView.leadingAnchor.constraint(equalTo: leadingAnchor),
            resultsView.trailingAnchor.constraint(equalTo: trailingAnchor),
            resultsView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func focusSearch() { window?.makeFirstResponder(searchField) }

    func controlTextDidChange(_ notification: Notification) {
        model.setQuery(searchField.stringValue)
    }
}
