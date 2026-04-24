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

    private var listContent: some View {
        List {
            if grouped.isEmpty {
                // Suche ist aktiv, aber keine Treffer -> Suchleiste bleibt vorhanden,
                // weil wir weiterhin eine List anzeigen.
                ContentUnavailableView(
                    "Keine Treffer",
                    systemImage: "magnifyingglass",
                    description: Text("Für „\(searchText)“ wurde nichts gefunden.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(grouped, id: \.key) { section in
                    Section {
                        ForEach(section.value) { item in
                            InventoryRow(item: item)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Text(section.key)
                            Spacer()
                            Text("\(section.value.count)")
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

    // MARK: - Filtering

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

    // MARK: - Grouping

    private var grouped: [(key: String, value: [UnitDisplayRow])] {
        let dict = Dictionary(grouping: filteredItems) { item in
            let emoji = item.category_emoji ?? "📦"
            let name = item.category_name ?? "Sonstiges"
            return "\(emoji) \(name)"
        }

        return dict.keys.sorted().map { key in
            let values = (dict[key] ?? [])
                .sorted { ($0.days_left ?? 999_999) < ($1.days_left ?? 999_999) }
            return (key: key, value: values)
        }
    }
}
