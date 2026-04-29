//
//  AttentionView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct AttentionView: View {
    @StateObject private var vm = AttentionViewModel()
    @State private var selectedGroup: InventoryGroup?
    @State private var selectedUnit: SelectedUnit?

    var body: some View {
        NavigationStack {
            List {
                if let msg = vm.errorMessage {
                    Section {
                        Text(msg).foregroundStyle(.red)
                    }
                }

                if !mhd2.isEmpty {
                    Section("max. 2 Tage") {
                        ForEach(groupedMhd2) { group in
                            attentionRow(for: group)
                        }
                    }
                }

                if !mhd7.isEmpty {
                    Section("max. 7 Tage") {
                        ForEach(groupedMhd7) { group in
                            attentionRow(for: group)
                        }
                    }
                }

                if mhd2.isEmpty && mhd7.isEmpty && vm.errorMessage == nil {
                    ContentUnavailableView(
                        "Nichts fällig",
                        systemImage: "checkmark.circle",
                        description: Text("Aktuell ist nichts in den nächsten 7 Tagen fällig.")
                    )
                }
            }
            .navigationTitle("Fällig")
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryDataDidChange)) { _ in
                Task { await vm.load() }
            }
        }
        .sheet(item: $selectedGroup) { group in
            InventoryGroupDetailView(ean: groupEAN(group), title: group.title)
        }
        .sheet(item: $selectedUnit) { sel in
            UnitDetailView(unitId: sel.id, displayName: sel.title)
        }
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

    private var mhd2: [UnitDisplayRow] {
        vm.items
            .filter { $0.attention_reason == "mhd_2" }
            .sorted(by: sortUnits)
    }

    private var mhd7: [UnitDisplayRow] {
        vm.items
            .filter { $0.attention_reason == "mhd_7" }
            .sorted(by: sortUnits)
    }

    private var groupedMhd2: [InventoryGroup] {
        groupedItems(from: mhd2)
    }

    private var groupedMhd7: [InventoryGroup] {
        groupedItems(from: mhd7)
    }

    @ViewBuilder
    private func attentionRow(for group: InventoryGroup) -> some View {
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

    private func groupedItems(from items: [UnitDisplayRow]) -> [InventoryGroup] {
        let dict = Dictionary(grouping: items) { item in
            if let ean = item.product_ean, !ean.isEmpty {
                return "EAN:\(ean)"
            }
            return "UNIT:\(item.id.uuidString)"
        }

        let mapped = dict.map { key, values in
            let sortedItems = values.sorted(by: sortUnits)
            let representative = sortedItems.first!
            let minDays = values.compactMap(\.days_left).min()
            let representativeFrozenISO = representative.frozen_at?.isEmpty == false ? representative.frozen_at : nil
            let emoji = representative.category_emoji ?? "📦"
            let catName = representative.category_name ?? "Sonstiges"

            return InventoryGroup(
                id: key,
                title: representative.display_name ?? "Unbenannt",
                categoryKey: "\(emoji) \(catName)",
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
