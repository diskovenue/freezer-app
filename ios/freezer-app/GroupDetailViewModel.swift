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
            items = try await repo.fetchUnitsByEAN(ean)
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
            let updatedItems = try await repo.fetchUnitsByEAN(ean)

            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = UndoItem(id: id, title: title ?? "Entnommen")
                items = updatedItems
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
            let updatedItems = try await repo.fetchUnitsByEAN(ean)

            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                undoItem = nil
                items = updatedItems
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
