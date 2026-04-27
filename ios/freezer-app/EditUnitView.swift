//
//  EditUnitView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI

struct EditUnitView: View {
    @ObservedObject var vm: UnitDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var nameOverride: String = ""
    @State private var frozenAt: String = ""     // ISO yyyy-MM-dd
    @State private var weightText: String = ""
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Bezeichnung") {
                    TextField("Name", text: $nameOverride)
                }

                Section("Eingelegt am (YYYY-MM-DD)") {
                    TextField("z.B. 2026-04-24", text: $frozenAt)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Gewicht (g)") {
                    TextField("z.B. 850", text: $weightText)
                        .keyboardType(.numberPad)
                }

                Section("Notiz") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task {
                            let weight = Int(weightText.trimmingCharacters(in: .whitespacesAndNewlines))
                            let name = nameOverride.trimmingCharacters(in: .whitespacesAndNewlines)
                            let frozen = frozenAt.trimmingCharacters(in: .whitespacesAndNewlines)
                            let noteTrim = note.trimmingCharacters(in: .whitespacesAndNewlines)

                            try? await vm.saveEdits(
                                nameOverride: name.isEmpty ? nil : name,
                                frozenAt: frozen.isEmpty ? nil : frozen,
                                weightG: weight,
                                note: noteTrim.isEmpty ? nil : noteTrim
                            )
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                // prefill from vm.unit
                nameOverride = vm.unit?.name_override ?? ""
                frozenAt = vm.unit?.frozen_at ?? ""
                if let w = vm.unit?.weight_g { weightText = "\(w)" }
                note = vm.unit?.note ?? ""
            }
        }
    }
}
