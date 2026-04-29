import Foundation
import Combine
import SwiftUI

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published var items: [UnitDisplayRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Undo banner state (lokal im Sheet)
    @Published var undoItem: UndoItem?

    struct UndoItem: Identifiable {
        let id: UUID
        let title: String
    }

    private let repo = InventoryRepository()
    private let ean: String
    let title: String

    init(ean: String, title: String) {
        self.ean = ean
        self.title = title
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loadedItems = try await repo.fetchUnitsByEAN(ean)
            withTransaction(Transaction(animation: nil)) {
                items = loadedItems
            }
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func consume(id: UUID, title: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let previousItems = items
        let optimisticItems = items.filter { $0.id != id }

        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            undoItem = UndoItem(id: id, title: title ?? "Entnommen")
            items = optimisticItems
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

        do {
            try await repo.consumeUnit(id: id)
            try? await Task.sleep(nanoseconds: 280_000_000)
            let updatedItems = try await repo.fetchUnitsByEAN(ean)
            withTransaction(Transaction(animation: nil)) {
                items = updatedItems
            }
            NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
        } catch {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = nil
                items = previousItems
            }
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
            let updatedItems = try await repo.fetchUnitsByEAN(ean)

            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = nil
                items = updatedItems
            }
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
