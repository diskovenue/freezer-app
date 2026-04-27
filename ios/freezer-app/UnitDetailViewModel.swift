//
//  UnitDetailViewModel.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import Foundation
import Combine

@MainActor
final class UnitDetailViewModel: ObservableObject {
    @Published var unit: FreezerUnit?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = InventoryRepository()
    private let unitId: UUID

    init(unitId: UUID) {
        self.unitId = unitId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            unit = try await repo.fetchUnit(id: unitId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func consume() async throws {
        try await repo.consumeUnit(id: unitId)
    }

    func saveEdits(
        nameOverride: String?,
        frozenAt: String?,
        weightG: Int?,
        note: String?
    ) async throws {
        try await repo.updateUnit(
            id: unitId,
            nameOverride: nameOverride,
            frozenAt: frozenAt,
            weightG: weightG,
            note: note
        )

        unit = try await repo.fetchUnit(id: unitId)
    }
}
