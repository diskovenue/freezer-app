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
    @Published var hasLoaded = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Undo banner state
    @Published var undoItem: UndoItem?

    private let repo = InventoryRepository()

    struct UndoItem: Identifiable {
        let id: UUID
        let title: String
    }

    init() {
        let cachedItems = ListCache.load(.inventory)
        if !cachedItems.isEmpty {
            items = cachedItems
            hasLoaded = true
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let loadedItems = try await repo.fetchUnitsDisplay()
            withTransaction(Transaction(animation: nil)) {
                items = loadedItems
            }
            ListCache.save(loadedItems, for: .inventory)
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func consume(id: UUID, title: String?, animateRemoval: Bool = true) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let previousItems = items
        let optimisticItems = items.filter { $0.id != id }

        if animateRemoval {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = UndoItem(id: id, title: title ?? "Entnommen")
                items = optimisticItems
            }
        } else {
            withTransaction(Transaction(animation: nil)) {
                undoItem = UndoItem(id: id, title: title ?? "Entnommen")
                items = optimisticItems
            }
        }
        ListCache.save(optimisticItems, for: .inventory)

        let current = undoItem?.id
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.undoItem?.id == current {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.undoItem = nil
                }
            }
        }

        do {
            try await repo.consumeUnit(id: id)
            try? await Task.sleep(nanoseconds: 280_000_000)
            let updatedItems = try await repo.fetchUnitsDisplay()
            withTransaction(Transaction(animation: nil)) {
                items = updatedItems
            }
            ListCache.save(updatedItems, for: .inventory)
            NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
        } catch {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = nil
                items = previousItems
            }
            ListCache.save(previousItems, for: .inventory)
            errorMessage = AppError.message(for: error)
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
            ListCache.save(updatedItems, for: .inventory)
            NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func presentUndoItem(id: UUID, title: String) {
        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            undoItem = UndoItem(id: id, title: title)
        }

        let current = undoItem?.id
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.undoItem?.id == current {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.undoItem = nil
                }
            }
        }
    }
}
