//
//  UnitDetailView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import SwiftUI
import PhotosUI

struct UnitDetailView: View {
    let unitId: UUID
    let displayName: String?
    let onConsumeClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: UnitDetailViewModel
    @State private var showEdit = false
    @State private var showPhotoSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showFullscreenPhoto = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(unitId: UUID, displayName: String?, onConsumeClose: (() -> Void)? = nil) {
        self.unitId = unitId
        self.displayName = displayName
        self.onConsumeClose = onConsumeClose
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
            .sheet(isPresented: $showPhotoSourceDialog) {
                PhotoActionsSheet(
                    hasPhoto: vm.photoImage != nil,
                    isBusy: vm.isPhotoUpdating,
                    onCamera: {
                        showPhotoSourceDialog = false
                        showCamera = true
                    },
                    onLibrary: {
                        showPhotoSourceDialog = false
                        showPhotoLibrary = true
                    },
                    onDelete: {
                        showPhotoSourceDialog = false
                        Task {
                            do {
                                try await vm.removePhoto()
                            } catch {
                                vm.errorMessage = AppError.message(for: error)
                            }
                        }
                    }
                )
                .presentationDetents(vm.photoImage == nil ? [.height(185)] : [.height(265)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color(.systemGroupedBackground))
            }
            .photosPicker(
                isPresented: $showPhotoLibrary,
                selection: $selectedPhotoItem,
                matching: .images,
                preferredItemEncoding: .automatic
            )
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    await loadSelectedPhotoItem(newValue)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker { image in
                    Task {
                        do {
                            try await vm.setPhoto(image)
                        } catch {
                            vm.errorMessage = AppError.message(for: error)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullscreenPhoto) {
                if let image = vm.photoImage {
                    PhotoFullscreenView(image: image)
                }
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
                            AppHaptics.selection()
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
            VStack(alignment: .leading, spacing: 14) {
                titleBlock

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
                        deadlineProgressModule(
                            frozenAt: displayUnit.frozen_at,
                            dueDate: displayUnit.due_date,
                            daysLeft: displayUnit.days_left
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

                photoCard

                Button {
                    AppHaptics.swipeAction()
                    Task {
                        do {
                            try await vm.consume()
                            if let onConsumeClose {
                                onConsumeClose()
                            } else {
                                dismiss()
                            }
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

    private var titleBlock: some View {
        Text(vm.resolvedDisplayName ?? "Unbenannt")
            .font(.system(size: 31, weight: .bold, design: .default))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var photoCard: some View {
        Group {
            if vm.photoImage == nil {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                        showPhotoSourceDialog = true
                    }
                } label: {
                    VStack(spacing: 14) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.12))
                            )

                        Text("Foto hinzufügen")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
                .disabled(vm.isPhotoUpdating)
            } else {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))

                    if let image = vm.photoImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 228)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay {
                                LinearGradient(
                                    colors: [.black.opacity(0.0), .black.opacity(0.12), .black.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                                    showPhotoSourceDialog = true
                                }
                            } label: {
                                Label("Ändern", systemImage: "camera.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .disabled(vm.isPhotoUpdating)
                        }
                    }
                    .padding(18)

                    if vm.isPhotoLoading || vm.isPhotoUpdating {
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(.black.opacity(0.18))
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                        }
                    }
                }
                .frame(height: 228)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .onTapGesture {
                    showFullscreenPhoto = true
                }
            }
        }
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

    @ViewBuilder
    private func deadlineProgressModule(frozenAt: String?, dueDate: String?, daysLeft: Int?) -> some View {
        if let frozenAt, let dueDate {
            HStack(alignment: .top, spacing: 12) {
                DetailIcon(symbol: "timer")

                VStack(alignment: .leading, spacing: 8) {
                    let progress = deadlineProgress(frozenAt: frozenAt, dueDate: dueDate)
                    let color = deadlineProgressColor(for: progress, daysLeft: daysLeft)

                    Text(deadlineDurationText(daysLeft: daysLeft))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(color)

                    deadlineProgressBar(
                        frozenAt: frozenAt,
                        dueDate: dueDate,
                        daysLeft: daysLeft
                    )
                }
            }
        }
    }

    private func deadlineProgressBar(frozenAt: String, dueDate: String, daysLeft: Int?) -> some View {
        let progress = deadlineProgress(frozenAt: frozenAt, dueDate: dueDate)
        let color = deadlineProgressColor(for: progress, daysLeft: daysLeft)

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.08))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: deadlineGradientColors(for: color),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, proxy.size.width * progress))

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color.opacity(0.28), radius: 6, y: 0)
                    .offset(x: max(0, min(proxy.size.width - 8, (proxy.size.width * progress) - 8)))
                    .opacity(progress > 0.02 ? 1 : 0)
            }
        }
        .frame(height: 8)
    }

    private func formatOptionalISODate(_ iso: String?) -> String? {
        guard let iso else { return nil }
        return formatISODate(iso)
    }

    private func formatISODate(_ iso: String) -> String {
        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "de_DE")
        outFmt.dateFormat = "dd.MM.yy"

        guard let d = parseISODate(iso) else { return iso }
        return outFmt.string(from: d)
    }

    private func parseISODate(_ iso: String) -> Date? {
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"
        return inFmt.date(from: iso)
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

    private func deadlineProgress(frozenAt: String, dueDate: String) -> CGFloat {
        guard
            let start = parseISODate(frozenAt),
            let end = parseISODate(dueDate)
        else { return 0 }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let today = calendar.startOfDay(for: Date())
        let total = endDay.timeIntervalSince(startDay)

        guard total > 0 else { return today < endDay ? 1 : 0 }

        if today >= endDay {
            return 1
        }

        let remaining = endDay.timeIntervalSince(today)
        return max(0, min(1, CGFloat(remaining / total)))
    }

    private func deadlineProgressColor(for progress: CGFloat, daysLeft: Int?) -> Color {
        if let daysLeft {
            if daysLeft <= 2 { return .red }
            if daysLeft <= 7 { return .yellow }
            return .green
        }

        if progress <= 0.18 { return .red }
        if progress <= 0.38 { return .yellow }
        return .green
    }

    private func deadlineGradientColors(for color: Color) -> [Color] {
        [color.opacity(0.72), color]
    }

    private func deadlineDurationText(daysLeft: Int?) -> String {
        guard let daysLeft else { return "Haltbarkeit" }
        if daysLeft < 0 { return "\(abs(daysLeft)) Tage drüber" }
        if daysLeft == 0 { return "Heute fällig" }
        if daysLeft == 1 { return "noch 1 Tag haltbar" }
        return "noch \(daysLeft) Tage haltbar"
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

    private func loadSelectedPhotoItem(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                return
            }
            try await vm.setPhoto(image)
        } catch {
            vm.errorMessage = AppError.message(for: error)
        }
    }
}

private struct PhotoActionsSheet: View {
    let hasPhoto: Bool
    let isBusy: Bool
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                actionButton(
                    title: "Foto aufnehmen",
                    subtitle: "Direkt mit der Kamera hinzufügen",
                    systemImage: "camera.fill",
                    tint: .accentColor,
                    action: onCamera
                )

                actionButton(
                    title: "Aus Fotos wählen",
                    subtitle: "Ein vorhandenes Bild auswählen",
                    systemImage: "photo.on.rectangle.angled",
                    tint: .accentColor,
                    action: onLibrary
                )

                if hasPhoto {
                    actionButton(
                        title: "Foto löschen",
                        subtitle: "Das aktuelle Bild entfernen",
                        systemImage: "trash.fill",
                        tint: .red,
                        action: onDelete
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 25)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 22))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .interactiveDismissDisabled(isBusy)
    }

    private func actionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.12))
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
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
