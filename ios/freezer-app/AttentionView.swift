//
//  AttentionView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct AttentionView: View {
    @StateObject private var vm = AttentionViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let msg = vm.errorMessage {
                    Section {
                        Text(msg).foregroundStyle(.red)
                    }
                }

                if !mhd2.isEmpty {
                    Section("≤ 2 Tage") {
                        ForEach(mhd2) { item in
                            InventoryRow(item: item)
                        }
                    }
                }

                if !mhd7.isEmpty {
                    Section("≤ 7 Tage") {
                        ForEach(mhd7) { item in
                            InventoryRow(item: item)
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
        }
    }

    private var mhd2: [UnitDisplayRow] {
        vm.items
            .filter { $0.attention_reason == "mhd_2" }
            .sorted { ($0.days_left ?? 999999) < ($1.days_left ?? 999999) }
    }

    private var mhd7: [UnitDisplayRow] {
        vm.items
            .filter { $0.attention_reason == "mhd_7" }
            .sorted { ($0.days_left ?? 999999) < ($1.days_left ?? 999999) }
    }
}
