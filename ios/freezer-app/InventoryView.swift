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
    }

    // MARK: - List

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
                            if group.count > 1 {
                                NavigationLink {
                                    InventoryGroupDetailView(group: group, vm: vm)
                                } label: {
                                    InventoryGroupRow(group: group)
                                }
                            } else {
                                InventoryGroupRow(group: group)
                                // später: Single-Detail-View
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Text(section.key)
                            Spacer()
                            // Anzahl Einheiten (nicht Anzahl Gruppen)
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

    // MARK: - Search filter (applies BEFORE grouping)

    private var filteredItems: [UnitDisplayRow] {
        let q = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

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
        // Gruppierung: EAN zusammen, alles ohne EAN einzeln
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

            // 1) dringendstes days_left innerhalb der Gruppe
            let minDays: Int? = values.compactMap(\.days_left).min()

            // 2) frühestes due_date innerhalb der Gruppe
            // due_date ist ISO "yyyy-MM-dd" -> lexikografisch min() entspricht frühestem Datum
            let minDueISO: String? = values
                .compactMap(\.due_date)
                .filter { !$0.isEmpty }
                .min()

            // sortiere Einheiten in der Gruppe (damit Detailview ordentlich ist)
            let sortedItems = values.sorted { ($0.days_left ?? 999_999) < ($1.days_left ?? 999_999) }

            return InventoryGroup(
                id: key,
                title: first.display_name ?? "Unbenannt",
                categoryKey: categoryKey,
                categoryName: first.category_name,
                categoryEmoji: first.category_emoji,
                locationName: first.location_name,
                minDaysLeft: minDays,
                minDueDateISO: minDueISO,
                count: values.count,
                items: sortedItems
            )
        }

        // Gruppen insgesamt nach Dringlichkeit sortieren
        return mapped.sorted { ($0.minDaysLeft ?? 999_999) < ($1.minDaysLeft ?? 999_999) }
    }

    // MARK: - Sections by category

    private var groupedSections: [(key: String, value: [InventoryGroup])] {
        let dict = Dictionary(grouping: groups) { $0.categoryKey }

        return dict.keys.sorted().map { key in
            let values = (dict[key] ?? []).sorted { ($0.minDaysLeft ?? 999_999) < ($1.minDaysLeft ?? 999_999) }
            return (key: key, value: values)
        }
    }
}
