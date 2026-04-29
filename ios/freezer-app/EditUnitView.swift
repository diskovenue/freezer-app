//
//  EditUnitView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI

struct EditUnitView: View {
    private enum QuantityUnit: String, CaseIterable, Identifiable {
        case grams = "g"
        case portions = "portionen"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .grams: "g"
            case .portions: "Portionen"
            }
        }
    }

    @ObservedObject var vm: UnitDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [CategoryRow] = []
    @State private var locations: [LocationRow] = []
    @State private var isLoadingReferenceData = false
    @State private var didPrefill = false
    @State private var nameOverride: String = ""
    @State private var hasFrozenAt = false
    @State private var frozenAtDate = Date()
    @State private var quantityText: String = ""
    @State private var quantityUnit: QuantityUnit = .grams
    @State private var selectedCategoryID: UUID?
    @State private var selectedLocationID: UUID?
    @State private var note: String = ""
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Bezeichnung") {
                    TextField("Name", text: $nameOverride)
                }

                Section("Zuordnung") {
                    NavigationLink {
                        CategorySelectionView(
                            categories: categories,
                            selectedCategoryID: $selectedCategoryID
                        )
                    } label: {
                        selectionRow(
                            title: "Kategorie",
                            value: selectedCategoryName
                        )
                    }

                    Menu {
                        Button {
                            selectedLocationID = nil
                        } label: {
                            if selectedLocationID == nil {
                                Label("Ort wählen", systemImage: "checkmark")
                            } else {
                                Text("Ort wählen")
                            }
                        }
                        ForEach(locations) { location in
                            Button {
                                selectedLocationID = location.id
                            } label: {
                                if selectedLocationID == location.id {
                                    Label(location.name, systemImage: "checkmark")
                                } else {
                                    Text(location.name)
                                }
                            }
                        }
                    } label: {
                        selectionRow(
                            title: "Ort",
                            value: selectedLocationName,
                            showsMenuIndicator: true
                        )
                    }
                    .foregroundStyle(.primary)
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

                Section("Menge") {
                    TextField(quantityUnit == .grams ? "z.B. 850" : "z.B. 3", text: $quantityText)
                        .keyboardType(.numberPad)

                    Picker("Einheit", selection: $quantityUnit) {
                        ForEach(QuantityUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
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
                            let quantity = Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
                            let name = nameOverride.trimmingCharacters(in: .whitespacesAndNewlines)
                            let noteTrim = note.trimmingCharacters(in: .whitespacesAndNewlines)

                            do {
                                try await vm.saveEdits(
                                    nameOverride: name.isEmpty ? nil : name,
                                    frozenAt: hasFrozenAt ? isoDateString(from: frozenAtDate) : nil,
                                    quantityValue: quantity,
                                    quantityUnit: quantity == nil ? nil : quantityUnit.rawValue,
                                    categoryId: selectedCategoryID,
                                    locationId: selectedLocationID ?? vm.unit?.location_id ?? UUID(),
                                    note: noteTrim.isEmpty ? nil : noteTrim
                                )
                                dismiss()
                            } catch {
                                alertMessage = AppError.message(for: error)
                            }
                        }
                    }
                    .disabled(isLoadingReferenceData || selectedLocationID == nil)
                }
            }
            .onAppear {
                guard !didPrefill else { return }
                didPrefill = true
                nameOverride = vm.editableName
                if let frozen = vm.unit?.frozen_at, let parsedDate = parseISODate(frozen) {
                    hasFrozenAt = true
                    frozenAtDate = parsedDate
                } else {
                    hasFrozenAt = false
                    frozenAtDate = Date()
                }
                quantityText = vm.editableQuantityValue
                quantityUnit = QuantityUnit(rawValue: vm.editableQuantityUnit) ?? .grams
                selectedCategoryID = vm.unit?.category_id
                selectedLocationID = vm.unit?.location_id
                note = vm.unit?.note ?? ""
            }
            .task {
                await loadReferenceData()
            }
            .alert("Speichern fehlgeschlagen", isPresented: editErrorIsPresented) {
                Button("OK", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "Bitte versuche es erneut.")
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

    private func loadReferenceData() async {
        guard categories.isEmpty, locations.isEmpty else { return }
        isLoadingReferenceData = true
        defer { isLoadingReferenceData = false }

        do {
            async let categoryRequest = CategoriesRepository().fetchCategories()
            async let locationRequest = LocationsRepository().fetchLocations()
            categories = try await categoryRequest
            locations = try await locationRequest
        } catch {
            alertMessage = AppError.message(for: error)
        }
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryID,
              let category = categories.first(where: { $0.id == selectedCategoryID }) else {
            return "Keine Kategorie"
        }

        if let emoji = category.emoji, !emoji.isEmpty {
            return "\(emoji) \(category.name)"
        }
        return category.name
    }

    private var selectedLocationName: String {
        guard let selectedLocationID,
              let location = locations.first(where: { $0.id == selectedLocationID }) else {
            return "Ort wählen"
        }
        return location.name
    }

    private func selectionRow(title: String, value: String, showsMenuIndicator: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.tertiary)
            if showsMenuIndicator {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var editErrorIsPresented: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { newValue in
                if !newValue {
                    alertMessage = nil
                }
            }
        )
    }
}

private struct CategorySelectionView: View {
    let categories: [CategoryRow]
    @Binding var selectedCategoryID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    selectedCategoryID = category.id
                    dismiss()
                } label: {
                    HStack {
                        Text(categoryLabel(category))
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedCategoryID == category.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Kategorie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryLabel(_ category: CategoryRow) -> String {
        if let emoji = category.emoji, !emoji.isEmpty {
            return "\(emoji) \(category.name)"
        }
        return category.name
    }
}
