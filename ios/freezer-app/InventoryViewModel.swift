//
//  InventoryViewModel.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var items: [UnitDisplayRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Undo banner state
    @Published var undoItem: UndoItem?

    private let repo = InventoryRepository()

    struct UndoItem: Identifiable {
        let id: UUID
        let title: String
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await repo.fetchUnitsDisplay()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func consume(id: UUID, title: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.consumeUnit(id: id)
            let updatedItems = try await repo.fetchUnitsDisplay()

            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = UndoItem(id: id, title: title ?? "Entnommen")
                items = updatedItems
            }

            // Banner nach ein paar Sekunden automatisch ausblenden
            let current = undoItem?.id
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self.undoItem?.id == current {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.undoItem = nil
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoLastConsume() async {
        guard let undo = undoItem else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.restoreUnit(id: undo.id)
            let updatedItems = try await repo.fetchUnitsDisplay()

            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = nil
                items = updatedItems
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
