//
//  UnitDetailView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI

struct UnitDetailView: View {
    let unitId: UUID
    let displayName: String?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: UnitDetailViewModel
    @State private var showEdit = false

    init(unitId: UUID, displayName: String?) {
        self.unitId = unitId
        self.displayName = displayName
        _vm = StateObject(wrappedValue: UnitDetailViewModel(unitId: unitId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.unit == nil {
                    ProgressView("Lade …")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let msg = vm.errorMessage {
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(msg)
                    )

                } else if let unit = vm.unit {
                    detailContent(unit)
                } else {
                    ContentUnavailableView(
                        "Keine Daten",
                        systemImage: "questionmark.folder",
                        description: Text("Der Eintrag konnte nicht geladen werden.")
                    )
                }
            }
            .navigationTitle(displayName ?? vm.unit?.name_override ?? "Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bearbeiten") { showEdit = true }
                        .disabled(vm.unit == nil)
                }
            }
            .task {
                await vm.load()
            }
            .sheet(isPresented: $showEdit) {
                EditUnitView(vm: vm)
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ unit: FreezerUnit) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Foto placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                    Text(unit.photo_path == nil ? "Kein Foto" : "Foto (kommt als nächstes)")
                        .foregroundStyle(.secondary)
                }
                .frame(height: 180)

                VStack(alignment: .leading, spacing: 10) {
                    metaRow("Typ", value: unit.code_type)
                    metaRow("Code", value: unit.code_value)
                    if let f = unit.frozen_at { metaRow("Eingelegt am", value: formatISODate(f)) }
                    if let w = unit.weight_g { metaRow("Gewicht", value: "\(w) g") }
                }
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let note = unit.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notiz").font(.headline)
                        Text(note)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    Task {
                        do {
                            try await vm.consume()
                            dismiss()
                        } catch {
                            vm.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Entnehmen", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(16)
        }
    }

    private func metaRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(.primary)
        }
        .font(.subheadline)
    }

    private func formatISODate(_ iso: String) -> String {
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"

        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "de_DE")
        outFmt.dateFormat = "dd.MM.yy"

        guard let d = inFmt.date(from: iso) else { return iso }
        return outFmt.string(from: d)
    }
}
