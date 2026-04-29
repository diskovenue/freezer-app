//
//  InventoryView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct InventoryView: View {
    private static let allCategoriesChipID = "__all_categories__"

    @StateObject private var vm = InventoryViewModel()
    @State private var searchText = ""
    @State private var chipScrollOffset: CGFloat = 0
    @State private var chipTrailingOverflow: CGFloat = 0
    @State private var selectedChipScrollID: String? = allCategoriesChipID

    @State private var selectedGroup: InventoryGroup?
    @State private var selectedUnit: SelectedUnit?

    // nil = Alle Kategorien
    @State private var selectedCategoryKey: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("Lade Bestand …")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let msg = vm.errorMessage, vm.items.isEmpty {
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(msg)
                    )

                } else if vm.items.isEmpty {
                    ContentUnavailableView(
                        "Noch nichts eingefroren",
                        systemImage: "tray",
                        description: Text("Scanne einen Sticker oder eine EAN und lege den ersten Eintrag an.")
                    )

                } else {
                    listContent
                }
            }
            .navigationTitle("Bestand")
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryDataDidChange)) { _ in
                Task { await vm.load() }
            }
        }
        // Group sheet
        .sheet(item: $selectedGroup) { group in
            InventoryGroupDetailView(ean: groupEAN(group), title: group.title)
        }
        // Unit detail sheet
        .sheet(item: $selectedUnit) { sel in
            UnitDetailView(unitId: sel.id, displayName: sel.title)
        }
        // Undo banner
        .overlay(alignment: .bottom) {
            if let undo = vm.undoItem {
                UndoBanner(
                    title: "\(undo.title) entnommen",
                    duration: 5,
                    onUndo: { Task { await vm.undoLastConsume() } },
                    onDismiss: { vm.undoItem = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: vm.undoItem?.id)
            }
        }
    }

    // MARK: - List

    private var listContent: some View {
        List {
            // Chips als LIST-HEADER (scrollt normal mit, refresh bleibt korrekt)
            chipsHeaderRow

            if groupedSections.isEmpty {
                ContentUnavailableView(
                    "Keine Treffer",
                    systemImage: "magnifyingglass",
                    description: Text("Für „\(searchText)“ wurde nichts gefunden.")
                )
                .listRowBackground(Color.clear)

            } else {
                ForEach(groupedSections, id: \.key) { section in
                    Section {
                        ForEach(section.value) { group in
                            Button {
                                if group.count > 1, group.id.hasPrefix("EAN:") {
                                    selectedGroup = group
                                } else if let first = group.items.first {
                                    selectedUnit = SelectedUnit(id: first.id, title: group.title)
                                }
                            } label: {
                                InventoryGroupRow(group: group)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task {
                                        if let first = group.items.first {
                                            await vm.consume(id: first.id, title: group.title)
                                        }
                                    }
                                } label: {
                                    Label("Entnehmen", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    } header: {
                        // Sticky Section-Header bleibt in List/Section automatisch
                        HStack(spacing: 8) {
                            Text(section.key)
                            Spacer()
                            Text("\(section.value.reduce(0) { $0 + $1.count })")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Suchen"
        )
        .scrollDismissesKeyboard(.immediately)
        .animation(.snappy(duration: 0.28, extraBounce: 0), value: selectedCategoryKey)
    }

    // MARK: - Chips header row

    @ViewBuilder
    private var chipsHeaderRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    CategoryChip(
                        title: "Alle",
                        count: totalUnitCountAllCategories,
                        isSelected: selectedCategoryKey == nil
                    ) {
                        selectedCategoryKey = nil
                        selectedChipScrollID = Self.allCategoriesChipID
                    }
                    .id(Self.allCategoriesChipID)

                    ForEach(categoryChipDataAllCategories, id: \.key) { entry in
                        CategoryChip(
                            title: entry.key,
                            count: entry.count,
                            isSelected: selectedCategoryKey == entry.key
                        ) {
                            if selectedCategoryKey == entry.key {
                                selectedCategoryKey = nil
                                selectedChipScrollID = Self.allCategoriesChipID
                            } else {
                                selectedCategoryKey = entry.key
                                selectedChipScrollID = chipScrollID(for: entry.key)
                            }
                        }
                        .id(chipScrollID(for: entry.key))
                    }
                }
                .padding(.vertical, 6)
            }
            .onScrollGeometryChange(for: ChipScrollMetrics.self) { geometry in
                ChipScrollMetrics(
                    offsetX: geometry.contentOffset.x,
                    trailingOverflow: geometry.contentSize.width - geometry.containerSize.width - geometry.contentOffset.x
                )
            } action: { _, newValue in
                chipScrollOffset = newValue.offsetX
                chipTrailingOverflow = newValue.trailingOverflow
            }
            .onChange(of: selectedChipScrollID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .mask {
            HStack(spacing: 0) {
                edgeMask(direction: .leading, isEnabled: chipScrollOffset > 1)
                Rectangle().fill(Color.black)
                edgeMask(direction: .trailing, isEnabled: chipTrailingOverflow > 1)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private enum FadeDirection {
        case leading
        case trailing
    }

    private struct ChipScrollMetrics: Equatable {
        let offsetX: CGFloat
        let trailingOverflow: CGFloat
    }

    private func chipScrollID(for key: String) -> String {
        "chip-\(key)"
    }

    @ViewBuilder
    private func edgeMask(direction: FadeDirection, isEnabled: Bool) -> some View {
        Group {
            if isEnabled {
                LinearGradient(
                    colors: direction == .leading
                        ? [Color.clear, Color.black]
                        : [Color.black, Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                Color.black
            }
        }
        .frame(width: 20)
    }

    private struct ChipEntry {
        let key: String
        let count: Int
    }

    // MARK: - Search filter

    private var filteredItems: [UnitDisplayRow] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.items }

        return vm.items.filter { item in
            let name = (item.display_name ?? "").lowercased()
            let cat  = (item.category_name ?? "").lowercased()
            let loc  = (item.location_name ?? "").lowercased()
            return name.contains(q) || cat.contains(q) || loc.contains(q)
        }
    }

    // MARK: - Base grouping (nur Suche wirkt)

    private var baseGroups: [InventoryGroup] {
        let dict = Dictionary(grouping: filteredItems) { item in
            if let ean = item.product_ean, !ean.isEmpty {
                return "EAN:\(ean)"
            }
            return "UNIT:\(item.id.uuidString)"
        }

        let mapped: [InventoryGroup] = dict.map { (key, values) in
            let sortedItems = values.sorted(by: sortUnits)
            let representative = sortedItems.first!

            let emoji = representative.category_emoji ?? "📦"
            let catName = representative.category_name ?? "Sonstiges"
            let categoryKey = "\(emoji) \(catName)"

            let minDays: Int? = values.compactMap(\.days_left).min()
            let representativeFrozenISO = representative.frozen_at?.isEmpty == false ? representative.frozen_at : nil

            return InventoryGroup(
                id: key,
                title: representative.display_name ?? "Unbenannt",
                categoryKey: categoryKey,
                categoryName: representative.category_name,
                categoryEmoji: representative.category_emoji,
                categorySortOrder: representative.category_sort_order,
                locationName: representative.location_name,
                minDaysLeft: minDays,
                minFrozenAtISO: representativeFrozenISO,
                count: values.count,
                items: sortedItems
            )
        }

        return mapped.sorted(by: sortGroups)
    }

    // MARK: - Chip data (immer alle sichtbar)

    private var totalUnitCountAllCategories: Int {
        baseGroups.reduce(0) { $0 + $1.count }
    }

    private var categoryChipDataAllCategories: [ChipEntry] {
        let dict = Dictionary(grouping: baseGroups) { $0.categoryKey }
        return orderedCategoryKeys(in: baseGroups).compactMap { key in
            guard let value = dict[key] else { return nil }
            return ChipEntry(key: key, count: value.reduce(0) { $0 + $1.count })
        }
    }

    // MARK: - Kategorie-Filter nach dem Gruppieren

    private var filteredGroupsByCategory: [InventoryGroup] {
        guard let selected = selectedCategoryKey else { return baseGroups }
        return baseGroups.filter { $0.categoryKey == selected }
    }

    private var groupedSections: [(key: String, value: [InventoryGroup])] {
        let dict = Dictionary(grouping: filteredGroupsByCategory) { $0.categoryKey }
        return orderedCategoryKeys(in: filteredGroupsByCategory).map { key in
            let values = (dict[key] ?? []).sorted(by: sortGroups)
            return (key: key, value: values)
        }
    }

    // MARK: - Helpers

    private struct SelectedUnit: Identifiable {
        let id: UUID
        let title: String?
    }

    private func groupEAN(_ group: InventoryGroup) -> String {
        if group.id.hasPrefix("EAN:") {
            return String(group.id.dropFirst(4))
        }
        return ""
    }

    private func orderedCategoryKeys(in groups: [InventoryGroup]) -> [String] {
        let groupedByCategory = Dictionary(grouping: groups) { $0.categoryKey }

        return groupedByCategory.keys.sorted { lhs, rhs in
            let lhsSortOrder = groupedByCategory[lhs]?.compactMap(\.categorySortOrder).min() ?? .max
            let rhsSortOrder = groupedByCategory[rhs]?.compactMap(\.categorySortOrder).min() ?? .max

            if lhsSortOrder != rhsSortOrder {
                return lhsSortOrder < rhsSortOrder
            }

            let lhsIndex = groups.firstIndex { $0.categoryKey == lhs } ?? .max
            let rhsIndex = groups.firstIndex { $0.categoryKey == rhs } ?? .max
            return lhsIndex < rhsIndex
        }
    }

    private func sortUnits(_ lhs: UnitDisplayRow, _ rhs: UnitDisplayRow) -> Bool {
        let lhsDays = lhs.days_left ?? 999_999
        let rhsDays = rhs.days_left ?? 999_999
        if lhsDays != rhsDays { return lhsDays < rhsDays }

        let lhsName = lhs.display_name ?? ""
        let rhsName = rhs.display_name ?? ""
        if lhsName != rhsName { return lhsName.localizedStandardCompare(rhsName) == .orderedAscending }

        let lhsFrozenAt = lhs.frozen_at ?? ""
        let rhsFrozenAt = rhs.frozen_at ?? ""
        if lhsFrozenAt != rhsFrozenAt { return lhsFrozenAt < rhsFrozenAt }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func sortGroups(_ lhs: InventoryGroup, _ rhs: InventoryGroup) -> Bool {
        let lhsDays = lhs.minDaysLeft ?? 999_999
        let rhsDays = rhs.minDaysLeft ?? 999_999
        if lhsDays != rhsDays { return lhsDays < rhsDays }

        let lhsTitle = lhs.title
        let rhsTitle = rhs.title
        if lhsTitle != rhsTitle { return lhsTitle.localizedStandardCompare(rhsTitle) == .orderedAscending }

        let lhsFrozenAt = lhs.minFrozenAtISO ?? ""
        let rhsFrozenAt = rhs.minFrozenAtISO ?? ""
        if lhsFrozenAt != rhsFrozenAt { return lhsFrozenAt < rhsFrozenAt }

        return lhs.id < rhs.id
    }
}
