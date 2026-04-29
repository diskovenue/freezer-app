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
    @State private var pendingConsume: PendingConsume?
    @State private var hiddenUnitIDs: Set<UUID> = []
    @State private var removingUnitIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                if !vm.hasLoaded {
                    loadingPlaceholderContent
                } else if let msg = vm.errorMessage {
                    Section {
                        Text(msg).foregroundStyle(.red)
                    }
                } else {
                    if !mhd2.isEmpty {
                        Section("max. 2 Tage") {
                            ForEach(Array(renderedGroupedMhd2.enumerated()), id: \.element.id) { index, group in
                                attentionRow(
                                    for: group,
                                    consumeDelayNanoseconds: consumeDelayNanoseconds(
                                        for: group,
                                        indexInSection: index,
                                        sectionCount: renderedGroupedMhd2.count
                                    )
                                )
                            }
                        }
                    }

                    if !mhd7.isEmpty {
                        Section("max. 7 Tage") {
                            ForEach(Array(renderedGroupedMhd7.enumerated()), id: \.element.id) { index, group in
                                attentionRow(
                                    for: group,
                                    consumeDelayNanoseconds: consumeDelayNanoseconds(
                                        for: group,
                                        indexInSection: index,
                                        sectionCount: renderedGroupedMhd7.count
                                    )
                                )
                            }
                        }
                    }

                    if vm.hasLoaded && !vm.isLoading && mhd2.isEmpty && mhd7.isEmpty && vm.errorMessage == nil {
                        emptyStateRow
                    }
                }
            }
            .overlay {
                if !vm.hasLoaded {
                    ProgressView("Lade Fälligkeiten …")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .navigationTitle("Fällig")
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
            .animation(.snappy(duration: 0.28, extraBounce: 0), value: vm.items.map(\.id))
            .animation(.snappy(duration: 0.18, extraBounce: 0), value: removingUnitIDs)
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
        .sheet(item: $selectedGroup) { group in
            InventoryGroupDetailView(
                ean: groupEAN(group),
                title: group.title,
                onConsumeClose: { selectedGroup = nil }
            )
        }
        .sheet(item: $selectedUnit) { sel in
            UnitDetailView(
                unitId: sel.id,
                displayName: sel.title,
                onConsumeClose: { selectedUnit = nil }
            )
        }
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

    private var mhd2: [UnitDisplayRow] {
        vm.items
            .filter { $0.attention_reason == "mhd_2" }
            .sorted(by: sortUnits)
    }

    private var loadingPlaceholderContent: some View {
        Group {
            Section("max. 2 Tage") {
                ForEach(0..<3, id: \.self) { _ in
                    placeholderRow
                }
            }

            Section("max. 7 Tage") {
                ForEach(0..<2, id: \.self) { _ in
                    placeholderRow
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    private var placeholderRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 160, height: 18)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 120, height: 13)
            }

            Spacer(minLength: 8)

            Capsule(style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 54, height: 28)
        }
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
        .allowsHitTesting(false)
    }

    private var emptyStateRow: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 60, height: 60)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 6) {
                Text("Nichts fällig")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Aktuell ist in den nächsten 7 Tagen nichts zu entnehmen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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

    private var renderedGroupedMhd2: [InventoryGroup] {
        groupedMhd2.filter { !isRemovingGroupRow($0) }
    }

    private var renderedGroupedMhd7: [InventoryGroup] {
        groupedMhd7.filter { !isRemovingGroupRow($0) }
    }

    @ViewBuilder
    private func attentionRow(
        for group: InventoryGroup,
        consumeDelayNanoseconds: UInt64
    ) -> some View {
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

    private func consumeDelayNanoseconds(
        for group: InventoryGroup,
        indexInSection: Int,
        sectionCount: Int
    ) -> UInt64 {
        if group.count == 1, indexInSection == sectionCount - 1 {
            return 650_000_000
        }
        return 300_000_000
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
