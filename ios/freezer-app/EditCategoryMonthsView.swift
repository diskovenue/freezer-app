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

    @Environment(\.dismiss) private var dismiss
    @State private var months: Int

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

            Section {
                Button("Speichern") {
                    Task {
                        await vm.updateMonths(categoryId: category.id, months: months)
                        dismiss()
                    }
                }
                .disabled(vm.isLoading)
            }
        }
        .navigationTitle("Bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
    }
}
