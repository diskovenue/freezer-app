//
//  CategorySettingsView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI

struct CategorySettingsView: View {
    @StateObject private var vm = CategoriesViewModel()
    @State private var showCreateCategory = false

    var body: some View {
        List {
            if let msg = vm.errorMessage {
                Section { Text(msg).foregroundStyle(.red) }
            }

            Section {
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
                .onMove { source, destination in
                    vm.moveCategories(from: source, to: destination)
                }
            } footer: {
                Text("Kategorien können per Drag & Drop sortiert werden.")
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Kategorien")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateCategory = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Kategorie hinzufügen")
            }
        }
        .sheet(isPresented: $showCreateCategory) {
            NavigationStack {
                EditCategoryMonthsView(category: nil, vm: vm)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 20)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}
