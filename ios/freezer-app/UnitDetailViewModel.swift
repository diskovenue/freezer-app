//
//  UnitDetailViewModel.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class UnitDetailViewModel: ObservableObject {
    @Published var unit: FreezerUnit?
    @Published var displayUnit: UnitDisplayRow?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var undoItem: UndoItem?

    private let repo = InventoryRepository()
    private let unitId: UUID
    private let initialDisplayName: String?

    struct UndoItem: Identifiable {
        let id: UUID
        let title: String
    }

    init(unitId: UUID, initialDisplayName: String?) {
        self.unitId = unitId
        self.initialDisplayName = initialDisplayName
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let unitRequest = repo.fetchUnit(id: unitId)
            async let displayUnitRequest = repo.fetchUnitDisplay(id: unitId)
            unit = try await unitRequest
            displayUnit = try await displayUnitRequest
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func consume() async throws {
        try await repo.consumeUnit(id: unitId)
        let title = unit?.name_override?.isEmpty == false ? unit?.name_override : nil

        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            undoItem = UndoItem(id: unitId, title: title ?? "Entnommen")
        }
        notifyInventoryDataChanged()

        let current = undoItem?.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.undoItem?.id == current {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.undoItem = nil
                }
            }
        }
    }

    func undoLastConsume() async throws {
        guard let undo = undoItem else { return }

        try await repo.restoreUnit(id: undo.id)
        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            undoItem = nil
        }
        notifyInventoryDataChanged()
    }

    func saveEdits(
        nameOverride: String?,
        frozenAt: String?,
        weightG: Int?,
        note: String?
    ) async throws {
        try await repo.updateUnit(
            id: unitId,
            nameOverride: nameOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            frozenAt: frozenAt,
            weightG: weightG,
            note: note
        )

        async let unitRequest = repo.fetchUnit(id: unitId)
        async let displayUnitRequest = repo.fetchUnitDisplay(id: unitId)
        unit = try await unitRequest
        displayUnit = try await displayUnitRequest
        notifyInventoryDataChanged()
    }

    private func notifyInventoryDataChanged() {
        NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
    }

    var resolvedDisplayName: String? {
        preferredNameOverride ?? initialDisplayName
    }

    var editableName: String {
        preferredNameOverride ?? initialDisplayName ?? ""
    }

    private var preferredNameOverride: String? {
        unit?.name_override?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
