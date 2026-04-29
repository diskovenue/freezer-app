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
        _vm = StateObject(wrappedValue: UnitDetailViewModel(unitId: unitId, initialDisplayName: displayName))
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
            .navigationTitle(vm.resolvedDisplayName ?? "Details")
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
            .overlay(alignment: .bottom) {
                if let undo = vm.undoItem {
                    UndoBanner(
                        title: "\(undo.title) entnommen",
                        duration: 5,
                        onUndo: {
                            Task {
                                do {
                                    try await vm.undoLastConsume()
                                } catch {
                                    vm.errorMessage = AppError.message(for: error)
                                }
                            }
                        },
                        onDismiss: { vm.undoItem = nil }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: vm.undoItem?.id)
                }
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ unit: FreezerUnit) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard(unit)

                if let displayUnit = vm.displayUnit {
                    detailCard("Übersicht") {
                        detailRow(
                            icon: "archivebox",
                            title: "Ort",
                            value: displayUnit.location_name
                        )
                        detailRow(
                            icon: "tag",
                            title: "Kategorie",
                            value: categoryLabel(for: displayUnit)
                        )
                        detailRow(
                            icon: "timer",
                            title: "Frist",
                            value: deadlineText(for: displayUnit.days_left),
                            valueColor: deadlineColor(for: displayUnit.days_left)
                        )
                    }
                }

                detailCard("Produkt") {
                    detailRow(
                        icon: "barcode.viewfinder",
                        title: "Code",
                        value: unit.code_value,
                        trailing: AnyView(CodeTypeBadge(title: codeTypeTitle(for: unit.code_type)))
                    )
                }

                detailCard("Details") {
                    detailRow(icon: "calendar", title: "Eingelegt am", value: formatOptionalISODate(unit.frozen_at))
                    detailRow(icon: "hourglass", title: "MHD", value: formatOptionalISODate(unit.best_before))
                    detailRow(icon: quantityIcon(for: unit), title: "Menge", value: quantityLabel(for: unit))
                }

                if let note = unit.note, !note.isEmpty {
                    detailCard("Notiz") {
                        HStack(alignment: .top, spacing: 12) {
                            DetailIcon(symbol: "note.text")

                            Text(note)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Button {
                    Task {
                        do {
                            try await vm.consume()
                        } catch {
                            vm.errorMessage = AppError.message(for: error)
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Label("Entnehmen", systemImage: "checkmark")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(vm.isLoading || vm.undoItem != nil)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func headerCard(_ unit: FreezerUnit) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))

                Image(systemName: unit.photo_path == nil ? "snowflake" : "photo")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.resolvedDisplayName ?? "Unbenannt")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                if unit.photo_path == nil {
                    Text("Kein Foto")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func detailCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func detailRow(
        icon: String,
        title: String,
        value: String?,
        trailing: AnyView? = nil,
        valueColor: Color = .primary
    ) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .center, spacing: 12) {
                DetailIcon(symbol: icon)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.body)
                        .foregroundStyle(valueColor)
                }

                Spacer(minLength: 12)

                if let trailing {
                    trailing
                }
            }
        }
    }

    private func formatOptionalISODate(_ iso: String?) -> String? {
        guard let iso else { return nil }
        return formatISODate(iso)
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

    private func codeTypeTitle(for codeType: String) -> String {
        let normalized = codeType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if normalized.contains("128") {
            return "CODE128"
        }

        if normalized.contains("EAN") {
            return "EAN"
        }

        return normalized
    }

    private func categoryLabel(for item: UnitDisplayRow) -> String? {
        let name = item.category_name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = item.category_emoji?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (emoji?.isEmpty == false ? emoji : nil, name?.isEmpty == false ? name : nil) {
        case let (emoji?, name?):
            return "\(emoji) \(name)"
        case let (_, name?):
            return name
        default:
            return nil
        }
    }

    private func deadlineText(for daysLeft: Int?) -> String? {
        guard let daysLeft else { return nil }
        if daysLeft < 0 { return "seit \(abs(daysLeft)) Tagen überschritten" }
        if daysLeft == 0 { return "heute fällig" }
        if daysLeft == 1 { return "morgen fällig" }
        return "in \(daysLeft) Tagen fällig"
    }

    private func deadlineColor(for daysLeft: Int?) -> Color {
        guard let daysLeft else { return .primary }
        if daysLeft <= 2 { return .red }
        if daysLeft <= 7 { return .orange }
        return .primary
    }

    private func quantityLabel(for unit: FreezerUnit) -> String? {
        if let value = unit.quantity_value {
            let normalizedUnit = unit.quantity_unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalizedUnit == "portionen" {
                return value == 1 ? "1 Portion" : "\(value) Portionen"
            }
            return "\(value) g"
        }

        if let weight = unit.weight_g {
            return "\(weight) g"
        }

        return nil
    }

    private func quantityIcon(for unit: FreezerUnit) -> String {
        let normalizedUnit = unit.quantity_unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedUnit == "portionen" ? "fork.knife" : "scalemass"
    }
}

private struct DetailIcon: View {
    let symbol: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))

            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 34, height: 34)
    }
}

private struct CodeTypeBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
    }
}
