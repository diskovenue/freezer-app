//
//  InventoryView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct InventoryView: View {
    @StateObject private var vm = InventoryViewModel()
    @State private var searchText = ""

    @State private var selectedGroup: InventoryGroup?
    @State private var selectedUnit: SelectedUnit?

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
        }
        // Group sheet
        .sheet(item: $selectedGroup) { group in
            InventoryGroupDetailView(ean: groupEAN(group), title: group.title)
        }
        
        // Unit detail sheet
        .sheet(item: $selectedUnit) { sel in
            UnitDetailView(unitId: sel.id, displayName: sel.title)
        }
        
        .overlay(alignment: .bottom) {
            if let undo = vm.undoItem {
                UndoBanner(
                    title: "\(undo.title) entnommen",
                    duration: 10,
                    onUndo: { Task { await vm.undoLastConsume() } },
                    onDismiss: { vm.undoItem = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: vm.undoItem?.id)
            }
        }
    }

    private var listContent: some View {
        List {
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

    // MARK: - Grouping (EAN grouped, non-EAN stays 1:1)
    private var groups: [InventoryGroup] {
        let dict = Dictionary(grouping: filteredItems) { item in
            if let ean = item.product_ean, !ean.isEmpty {
                return "EAN:\(ean)"
            }
            return "UNIT:\(item.id.uuidString)"
        }

        let mapped: [InventoryGroup] = dict.map { (key, values) in
            let first = values.first!

            let emoji = first.category_emoji ?? "📦"
            let catName = first.category_name ?? "Sonstiges"
            let categoryKey = "\(emoji) \(catName)"

            let minDays: Int? = values.compactMap(\.days_left).min()
            let minFrozenISO: String? = values
                .compactMap(\.frozen_at)
                .filter { !$0.isEmpty }
                .min()

            let sortedItems = values.sorted { ($0.days_left ?? 999_999) < ($1.days_left ?? 999_999) }

            return InventoryGroup(
                id: key,
                title: first.display_name ?? "Unbenannt",
                categoryKey: categoryKey,
                categoryName: first.category_name,
                categoryEmoji: first.category_emoji,
                locationName: first.location_name,
                minDaysLeft: minDays,
                minFrozenAtISO: minFrozenISO,
                count: values.count,
                items: sortedItems
            )
        }

        return mapped.sorted { ($0.minDaysLeft ?? 999_999) < ($1.minDaysLeft ?? 999_999) }
    }

    private var groupedSections: [(key: String, value: [InventoryGroup])] {
        let dict = Dictionary(grouping: groups) { $0.categoryKey }
        return dict.keys.sorted().map { key in
            let values = (dict[key] ?? []).sorted { ($0.minDaysLeft ?? 999_999) < ($1.minDaysLeft ?? 999_999) }
            return (key: key, value: values)
        }
    }

    private struct SelectedUnit: Identifiable {
        let id: UUID
        let title: String?
    }
    
    private func groupEAN(_ group: InventoryGroup) -> String {
        // group.id ist "EAN:4000..." oder "UNIT:..."
        if group.id.hasPrefix("EAN:") {
            return String(group.id.dropFirst(4))
        }
        // sollte für Group-Sheet nie passieren, weil wir es nur bei count>1 öffnen
        return ""
    }
}
