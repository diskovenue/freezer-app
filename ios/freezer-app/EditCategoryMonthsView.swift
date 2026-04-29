//
//  EditCategoryMonthsView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI

struct EditCategoryMonthsView: View {
    let category: CategoryRow
    @ObservedObject var vm: CategoriesViewModel

    @State private var months: Int
    @State private var saveTask: Task<Void, Never>?

    init(category: CategoryRow, vm: CategoriesViewModel) {
        self.category = category
        self.vm = vm
        _months = State(initialValue: category.freezer_months)
    }

    var body: some View {
        Form {
            Section("Kategorie") {
                HStack(spacing: 12) {
                    Text(category.emoji ?? "📦").font(.title2)
                    Text(category.name).font(.headline)
                }
            }

            Section("Gefrierfrist") {
                Stepper(value: $months, in: 1...24) {
                    Text("\(months) Monate")
                }
                Text("Tipp: Wenn du lieber rechtzeitig erinnert werden willst, setze die Frist eher konservativ.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: months) { _, newValue in
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await vm.updateMonths(categoryId: category.id, months: newValue)
            }
        }
        .onDisappear {
            saveTask?.cancel()
        }
    }
}
