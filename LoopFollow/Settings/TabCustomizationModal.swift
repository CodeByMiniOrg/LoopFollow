// LoopFollow
// TabCustomizationModal.swift

import SwiftUI

struct TabCustomizationModal: View {
    @Binding var isPresented: Bool
    let onApply: () -> Void

    // The ordered list of items in the tab bar (positions 1-5)
    @State private var tabBarItems: [TabItem]
    // Items in the "More" menu
    @State private var moreItems: [TabItem]
    // Items that are hidden
    @State private var hiddenItems: [TabItem]

    @State private var hasChanges = false

    // Store originals for comparison
    private let originalTabBarItems: [TabItem]
    private let originalMoreItems: [TabItem]
    private let originalHiddenItems: [TabItem]

    init(isPresented: Binding<Bool>, onApply: @escaping () -> Void) {
        _isPresented = isPresented
        self.onApply = onApply

        // Build current state from storage
        var tabBar: [TabItem] = []
        var more: [TabItem] = []
        var hidden: [TabItem] = []
        var assignedItems = Set<TabItem>()

        // Get items for each position in the tab bar (in order)
        for position in TabPosition.tabBarPositions {
            if let item = Storage.shared.tabItem(at: position), !assignedItems.contains(item) {
                tabBar.append(item)
                assignedItems.insert(item)
            }
        }

        // Assign remaining items to more or hidden based on their stored position
        for item in TabItem.allCases where !assignedItems.contains(item) {
            let pos = Storage.shared.position(for: item)
            if pos == .disabled {
                hidden.append(item)
            } else {
                // Everything else (including .more and any orphaned tab positions) goes to More
                more.append(item)
            }
            assignedItems.insert(item)
        }

        _tabBarItems = State(initialValue: tabBar)
        _moreItems = State(initialValue: more)
        _hiddenItems = State(initialValue: hidden)

        originalTabBarItems = tabBar
        originalMoreItems = more
        originalHiddenItems = hidden
    }

    private var canAddToTabBar: Bool {
        tabBarItems.count < 5
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Drag to reorder tabs. The first tab is shown when the app opens.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    ForEach(tabBarItems) { item in
                        TabItemRowView(item: item)
                    }
                    .onMove { from, to in
                        tabBarItems.move(fromOffsets: from, toOffset: to)
                        checkForChanges()
                    }
                    .onDelete { indexSet in
                        // Move deleted items to More
                        let items = indexSet.map { tabBarItems[$0] }
                        tabBarItems.remove(atOffsets: indexSet)
                        moreItems.append(contentsOf: items)
                        checkForChanges()
                    }
                } header: {
                    HStack {
                        Text("Tab Bar")
                        Spacer()
                        Text("\(tabBarItems.count)/5")
                            .foregroundColor(tabBarItems.count == 5 ? .orange : .secondary)
                    }
                }

                if !moreItems.isEmpty {
                    Section {
                        ForEach(moreItems) { item in
                            HStack {
                                TabItemRowView(item: item)

                                if canAddToTabBar {
                                    Button {
                                        withAnimation {
                                            addToTabBar(item)
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.green)
                                            .imageScale(.large)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    moveToHidden(item, from: &moreItems)
                                } label: {
                                    Label("Hide", systemImage: "eye.slash")
                                }
                            }
                        }
                        .onMove { from, to in
                            moreItems.move(fromOffsets: from, toOffset: to)
                            checkForChanges()
                        }
                    } header: {
                        HStack {
                            Text("More Menu")
                            Spacer()
                            if canAddToTabBar {
                                Text("Tap + to add to Tab Bar")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !hiddenItems.isEmpty {
                    Section("Hidden") {
                        ForEach(hiddenItems) { item in
                            HStack {
                                TabItemRowView(item: item)
                                    .opacity(0.6)

                                Button {
                                    withAnimation {
                                        moveToMore(item, from: &hiddenItems)
                                    }
                                } label: {
                                    Image(systemName: "arrow.uturn.up.circle.fill")
                                        .foregroundColor(.orange)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.plain)

                                if canAddToTabBar {
                                    Button {
                                        withAnimation {
                                            moveToTabBar(item, from: &hiddenItems)
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.green)
                                            .imageScale(.large)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if moreItems.isEmpty && hiddenItems.isEmpty {
                    Section {
                        Text("All items are in the tab bar. Swipe left on a tab to remove it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if hasChanges {
                    Section {
                        Text("Changes will be applied when you tap 'Apply'")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Tab Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
    }

    private func addToTabBar(_ item: TabItem) {
        guard canAddToTabBar else { return }
        moreItems.removeAll { $0 == item }
        tabBarItems.append(item)
        checkForChanges()
    }

    private func moveToTabBar(_ item: TabItem, from source: inout [TabItem]) {
        guard canAddToTabBar else { return }
        source.removeAll { $0 == item }
        tabBarItems.append(item)
        checkForChanges()
    }

    private func moveToMore(_ item: TabItem, from source: inout [TabItem]) {
        source.removeAll { $0 == item }
        moreItems.append(item)
        checkForChanges()
    }

    private func moveToHidden(_ item: TabItem, from source: inout [TabItem]) {
        source.removeAll { $0 == item }
        hiddenItems.append(item)
        checkForChanges()
    }

    private func checkForChanges() {
        hasChanges = tabBarItems != originalTabBarItems ||
            moreItems != originalMoreItems ||
            hiddenItems != originalHiddenItems
    }

    private func applyChanges() {
        // Save tab bar positions (index 0 = position1, etc.)
        for (index, item) in tabBarItems.enumerated() {
            let position: TabPosition
            switch index {
            case 0: position = .position1
            case 1: position = .position2
            case 2: position = .position3
            case 3: position = .position4
            case 4: position = .position5
            default: position = .more
            }
            Storage.shared.setPosition(position, for: item)
        }

        // Save more items
        for item in moreItems {
            Storage.shared.setPosition(.more, for: item)
        }

        // Save hidden items
        for item in hiddenItems {
            Storage.shared.setPosition(.disabled, for: item)
        }

        // Dismiss the modal
        isPresented = false

        // Call the completion handler after a small delay to ensure modal is dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onApply()
        }
    }
}

struct TabItemRowView: View {
    let item: TabItem

    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .frame(width: 30)
                .foregroundColor(.accentColor)

            Text(item.displayName)

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
