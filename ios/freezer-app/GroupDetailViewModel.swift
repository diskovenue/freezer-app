import Foundation
import Combine
import SwiftUI

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published var items: [UnitDisplayRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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

    func consume(id: UUID, title: String?) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let previousItems = items
        let optimisticItems = items.filter { $0.id != id }
        let consumedTitle = title ?? "Entnommen"

        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            items = optimisticItems
        }

        do {
            let photoPath = try await repo.consumeUnit(id: id)
            if let photoPath {
                PendingPhotoDeletionStore.shared.scheduleDeletion(for: id, path: photoPath)
            }
            try? await Task.sleep(nanoseconds: 280_000_000)
            let updatedItems = try await repo.fetchUnitsByEAN(ean)
            withTransaction(Transaction(animation: nil)) {
                items = updatedItems
            }
            NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
            NotificationCenter.default.post(
                name: .unitDetailDidConsume,
                object: nil,
                userInfo: [
                    AppNotificationKey.unitID: id,
                    AppNotificationKey.title: consumedTitle
                ]
            )
            return true
        } catch {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                items = previousItems
            }
            errorMessage = AppError.message(for: error)
            return false
        }
    }
}
