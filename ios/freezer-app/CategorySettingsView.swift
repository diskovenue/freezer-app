//
//  CategorySettingsView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI

struct CategorySettingsView: View {
    @StateObject private var vm = CategoriesViewModel()

    var body: some View {
        List {
            if let msg = vm.errorMessage {
                Section { Text(msg).foregroundStyle(.red) }
            }

            ForEach(vm.items) { cat in
                NavigationLink {
                    EditCategoryMonthsView(category: cat, vm: vm)
                } label: {
                    HStack(spacing: 12) {
                        Text(cat.emoji ?? "📦")
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.name)
                                .font(.headline)

                            Text("Gefrierfrist: \(cat.freezer_months) Monate")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Kategorien")
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}
