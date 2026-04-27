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
    @State private var hasFrozenAt = false
    @State private var frozenAtDate = Date()
    @State private var weightText: String = ""
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Bezeichnung") {
                    TextField("Name", text: $nameOverride)
                }

                Section("Eingelegt am") {
                    Toggle("Datum gesetzt", isOn: $hasFrozenAt)

                    if hasFrozenAt {
                        DatePicker(
                            "Datum",
                            selection: $frozenAtDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }
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
                            let noteTrim = note.trimmingCharacters(in: .whitespacesAndNewlines)

                            try? await vm.saveEdits(
                                nameOverride: name.isEmpty ? nil : name,
                                frozenAt: hasFrozenAt ? isoDateString(from: frozenAtDate) : nil,
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
                nameOverride = vm.editableName
                if let frozen = vm.unit?.frozen_at, let parsedDate = parseISODate(frozen) {
                    hasFrozenAt = true
                    frozenAtDate = parsedDate
                } else {
                    hasFrozenAt = false
                    frozenAtDate = Date()
                }
                if let w = vm.unit?.weight_g { weightText = "\(w)" }
                note = vm.unit?.note ?? ""
            }
        }
    }

    private func parseISODate(_ iso: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }

    private func isoDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
