import SwiftUI

struct EditLocationView: View {
    let location: LocationRow?
    @ObservedObject var vm: LocationsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var validationMessage: String?
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var blockedDeleteCount: Int?

    init(location: LocationRow?, vm: LocationsViewModel) {
        self.location = location
        self.vm = vm
        _name = State(initialValue: location?.name ?? "")
    }

    var body: some View {
        Form {
            Section("Ort") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            if location != nil {
                Section {
                    Button("Ort löschen", role: .destructive) {
                        prepareDelete()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle(location == nil ? "Neuer Ort" : "Bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if location == nil {
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
        .alert("Ort löschen?", isPresented: $showDeleteConfirmation) {
            Button("Ort löschen", role: .destructive) {
                deleteLocation()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dieser Ort enthält keine Einträge und wird gelöscht.")
        }
        .alert("Ort kann nicht gelöscht werden", isPresented: blockedDeleteAlertBinding) {
            Button("OK", role: .cancel) {
                blockedDeleteCount = nil
            }
        } message: {
            Text(blockedDeleteMessage)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte einen Namen eingeben."
            return
        }

        Task {
            isSaving = true
            defer { isSaving = false }

            let didSave = await vm.saveLocation(locationId: location?.id, name: trimmedName)
            if didSave {
                dismiss()
            }
        }
    }

    private func prepareDelete() {
        guard let location else { return }

        Task {
            isSaving = true
            defer { isSaving = false }

            guard let count = await vm.countUnits(locationId: location.id) else { return }
            if count == 0 {
                showDeleteConfirmation = true
            } else {
                blockedDeleteCount = count
            }
        }
    }

    private func deleteLocation() {
        guard let location else { return }

        Task {
            isSaving = true
            defer { isSaving = false }

            let didDelete = await vm.deleteLocation(locationId: location.id)
            if didDelete {
                dismiss()
            }
        }
    }

    private var blockedDeleteMessage: String {
        guard let blockedDeleteCount else {
            return "Diesem Ort sind noch Einträge zugeordnet."
        }

        if blockedDeleteCount == 1 {
            return "Diesem Ort ist noch 1 Eintrag zugeordnet. Bitte ändere den Ort dieses Eintrags zuerst."
        }

        return "Diesem Ort sind noch \(blockedDeleteCount) Einträge zugeordnet. Bitte ändere den Ort dieser Einträge zuerst."
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

    private var blockedDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { blockedDeleteCount != nil },
            set: { isPresented in
                if !isPresented {
                    blockedDeleteCount = nil
                }
            }
        )
    }
}
