//
//  EditCategoryMonthsView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI

struct EditCategoryMonthsView: View {
    let category: CategoryRow?
    @ObservedObject var vm: CategoriesViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var months: Int
    @State private var validationMessage: String?
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var affectedUnitCount: Int?

    init(category: CategoryRow?, vm: CategoriesViewModel) {
        self.category = category
        self.vm = vm
        _name = State(initialValue: category?.name ?? "")
        _emoji = State(initialValue: category?.emoji ?? "")
        _months = State(initialValue: category?.freezer_months ?? 6)
    }

    var body: some View {
        Form {
            Section("Kategorie") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)

                TextField("Emoji", text: $emoji)
                    .onChange(of: emoji) { _, newValue in
                        emoji = String(newValue.prefix(2))
                    }
            }

            Section("Gefrierfrist") {
                Stepper(value: $months, in: 1...24) {
                    Text("\(months) Monate")
                }

                Text("Diese Frist wird beim Anlegen neuer Einträge als Standard für die Kategorie verwendet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if category != nil {
                Section {
                    Button("Kategorie löschen", role: .destructive) {
                        prepareDeleteConfirmation()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle(category == nil ? "Neue Kategorie" : "Bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if category == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    save()
                }
                .disabled(isSaving)
            }
        }
        .alert("Unvollständig", isPresented: validationAlertBinding) {
            Button("OK", role: .cancel) {
                validationMessage = nil
            }
        } message: {
            Text(validationMessage ?? "Bitte prüfe deine Eingaben.")
        }
        .alert("Kategorie löschen?", isPresented: $showDeleteConfirmation) {
            Button("Kategorie löschen", role: .destructive) {
                deleteCategory()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte einen Namen eingeben."
            return
        }

        Task {
            isSaving = true
            defer { isSaving = false }

            let didSave = await vm.saveCategory(
                categoryId: category?.id,
                name: trimmedName,
                emoji: trimmedEmoji.isEmpty ? nil : trimmedEmoji,
                freezerMonths: months
            )

            if didSave {
                dismiss()
            }
        }
    }

    private func deleteCategory() {
        guard let category else { return }

        Task {
            isSaving = true
            defer { isSaving = false }

            let didDelete = await vm.deleteCategory(categoryId: category.id)
            if didDelete {
                dismiss()
            }
        }
    }

    private func prepareDeleteConfirmation() {
        guard let category else { return }

        Task {
            isSaving = true
            defer { isSaving = false }

            affectedUnitCount = await vm.countUnits(categoryId: category.id)
            showDeleteConfirmation = affectedUnitCount != nil
        }
    }

    private var deleteConfirmationMessage: String {
        guard let affectedUnitCount else {
            return "Einträge aus dieser Kategorie werden nach \"Sonstiges\" verschoben."
        }

        if affectedUnitCount == 0 {
            return "Diese Kategorie enthält keine Einträge und wird gelöscht."
        }

        if affectedUnitCount == 1 {
            return "1 Eintrag aus dieser Kategorie wird nach \"Sonstiges\" verschoben."
        }

        return "\(affectedUnitCount) Einträge aus dieser Kategorie werden nach \"Sonstiges\" verschoben."
    }

    private var validationAlertBinding: Binding<Bool> {
        Binding(
            get: { validationMessage != nil },
            set: { isPresented in
                if !isPresented {
                    validationMessage = nil
                }
            }
        )
    }
}
