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
    @State private var pendingConsume: PendingConsume?
    @State private var hiddenUnitIDs: Set<UUID> = []
    @State private var removingUnitIDs: Set<UUID> = []

    // nil = Alle Kategorien
    @State private var selectedCategoryKey: String? = nil

    var body: some View {
        NavigationStack {
            listContent
                .overlay {
                    if !vm.hasLoaded {
                        ProgressView("Lade Bestand …")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    } else if let msg = vm.errorMessage, vm.items.isEmpty {
                        ContentUnavailableView(
                            "Fehler",
                            systemImage: "exclamationmark.triangle",
                            description: Text(msg)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.hasLoaded && vm.items.isEmpty {
                        ContentUnavailableView(
                            "Noch nichts eingefroren",
                            systemImage: "tray",
                            description: Text("Scanne einen Sticker oder eine EAN und lege den ersten Eintrag an.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationTitle("Bestand")
                .task { await vm.load() }
                .refreshable { await vm.load() }
                .onReceive(NotificationCenter.default.publisher(for: .inventoryDataDidChange)) { _ in
                    Task { await vm.load() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .unitDetailDidConsume)) { notification in
                    guard
                        let id = notification.userInfo?[AppNotificationKey.unitID] as? UUID,
                        let title = notification.userInfo?[AppNotificationKey.title] as? String
                    else { return }
                    vm.presentUndoItem(id: id, title: title)
                }
                .onChange(of: pendingConsume?.id) { _, newValue in
                    guard newValue != nil, let pending = pendingConsume else { return }
                    Task {
                    try? await Task.sleep(nanoseconds: pending.delayNanoseconds)
                    await vm.consume(id: pending.id, title: pending.title, animateRemoval: pending.animateRemoval)
                    hiddenUnitIDs.remove(pending.id)
                    removingUnitIDs.remove(pending.id)
                    if pendingConsume?.id == pending.id {
                        pendingConsume = nil
                    }
                }
            }
        }
        // Group sheet
        .sheet(item: $selectedGroup) { group in
            InventoryGroupDetailView(
                ean: groupEAN(group),
                title: group.title,
                onConsumeClose: { selectedGroup = nil }
            )
        }
        // Unit detail sheet
        .sheet(item: $selectedUnit) { sel in
            UnitDetailView(
                unitId: sel.id,
                displayName: sel.title,
                onConsumeClose: { selectedUnit = nil }
            )
        }
        // Undo banner
        .overlay(alignment: .bottom) {
            if let undo = vm.undoItem {
                UndoBanner(
                    title: "\(undo.title) entnommen",
                    duration: 5,
                    onUndo: {
                        AppHaptics.selection()
                        Task { await vm.undoLastConsume() }
                    },
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
            if !vm.hasLoaded {
                loadingPlaceholderContent
            } else if !vm.items.isEmpty {
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
                    ForEach(renderedGroupedSections, id: \.key) { section in
                        Section {
                            ForEach(Array(section.value.enumerated()), id: \.element.id) { index, group in
                                groupRow(
                                    group,
                                    consumeDelayNanoseconds: consumeDelayNanoseconds(
                                        for: group,
                                        indexInSection: index,
                                        sectionCount: section.value.count
                                    )
                                )
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
                            .zIndex(0)
                        }
                    }
                }
            } else {
                Color.clear
                    .frame(height: 1)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityHidden(true)
            }
        }
        .listStyle(.insetGrouped)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Suchen"
        )
        .scrollDismissesKeyboard(.immediately)
        .animation(.snappy(duration: 0.28, extraBounce: 0), value: vm.items.map(\.id))
        .animation(.snappy(duration: 0.18, extraBounce: 0), value: removingUnitIDs)
        .animation(.snappy(duration: 0.28, extraBounce: 0), value: selectedCategoryKey)
    }

    private var loadingPlaceholderContent: some View {
        Group {
            loadingPlaceholderChipsRow

            Section {
                ForEach(0..<4, id: \.self) { _ in
                    placeholderRow
                }
            } header: {
                placeholderSectionHeader
            }

            Section {
                ForEach(0..<3, id: \.self) { _ in
                    placeholderRow
                }
            } header: {
                placeholderSectionHeader
            }
        }
    }

    private var loadingPlaceholderChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: [74, 106, 92, 118][index], height: 34)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(.vertical, 6)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .allowsHitTesting(false)
    }

    private var placeholderSectionHeader: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 120, height: 14)
            Spacer()
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 20, height: 14)
        }
        .redacted(reason: .placeholder)
        .textCase(nil)
    }

    private var placeholderRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 170, height: 18)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 130, height: 13)
            }

            Spacer(minLength: 8)

            Capsule(style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 54, height: 28)
        }
        .padding(.vertical, 6)
        .redacted(reason: .placeholder)
        .listRowSeparator(.hidden)
        .allowsHitTesting(false)
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
                        AppHaptics.selection()
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
                            AppHaptics.selection()
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

    private var renderedGroupedSections: [(key: String, value: [InventoryGroup])] {
        groupedSections.compactMap { section in
            let visibleGroups = section.value.filter { !isRemovingGroupRow($0) }
            guard !visibleGroups.isEmpty else { return nil }
            return (key: section.key, value: visibleGroups)
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

    @ViewBuilder
    private func groupRow(_ group: InventoryGroup, consumeDelayNanoseconds: UInt64) -> some View {
        Button {
            if group.count > 1, group.id.hasPrefix("EAN:") {
                selectedGroup = group
            } else if let first = group.items.first {
                selectedUnit = SelectedUnit(id: first.id, title: group.title)
            }
        } label: {
            InventoryGroupRow(group: group)
        }
        .opacity(isHiddenGroupRow(group) ? 0 : 1)
        .listRowBackground(isHiddenGroupRow(group) ? AnyView(Color.clear) : AnyView(Color(uiColor: .secondarySystemGroupedBackground)))
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                if let first = group.items.first {
                    AppHaptics.swipeAction()
                    if group.count == 1 {
                        hiddenUnitIDs.insert(first.id)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 70_000_000)
                            _ = withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                                removingUnitIDs.insert(first.id)
                            }
                        }
                    }
                    pendingConsume = PendingConsume(
                        id: first.id,
                        title: group.title,
                        delayNanoseconds: consumeDelayNanoseconds,
                        animateRemoval: shouldAnimateRemovingGroupRow(
                            group,
                            consumeDelayNanoseconds: consumeDelayNanoseconds
                        )
                    )
                }
            } label: {
                Label("Entnehmen", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }

    private func consumeDelayNanoseconds(for group: InventoryGroup, indexInSection: Int, sectionCount: Int) -> UInt64 {
        let defaultDelay: UInt64 = 300_000_000
        let lastSingleItemInSection = group.count == 1 && indexInSection == sectionCount - 1
        return lastSingleItemInSection ? 650_000_000 : defaultDelay
    }

    private struct PendingConsume: Identifiable {
        let id: UUID
        let title: String?
        let delayNanoseconds: UInt64
        let animateRemoval: Bool
    }

    private func isRemovingGroupRow(_ group: InventoryGroup) -> Bool {
        guard group.count == 1, let first = group.items.first else { return false }
        return removingUnitIDs.contains(first.id)
    }

    private func isHiddenGroupRow(_ group: InventoryGroup) -> Bool {
        guard group.count == 1, let first = group.items.first else { return false }
        return hiddenUnitIDs.contains(first.id)
    }

    private func shouldAnimateRemovingGroupRow(
        _ group: InventoryGroup,
        consumeDelayNanoseconds: UInt64
    ) -> Bool {
        !(group.count == 1 && consumeDelayNanoseconds > 300_000_000)
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
