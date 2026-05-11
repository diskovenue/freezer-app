import Foundation
import Combine

@MainActor
final class LocationsViewModel: ObservableObject {
    @Published var items: [LocationRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = LocationsRepository()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await repo.fetchLocations()
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func saveLocation(locationId: UUID?, name: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let locationId {
                try await repo.updateLocation(locationId: locationId, name: name)
            } else {
                try await repo.createLocation(name: name, sortOrder: nextSortOrder)
            }

            items = try await repo.fetchLocations()
            NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
            return true
        } catch {
            errorMessage = AppError.message(for: error)
            return false
        }
    }

    func moveLocations(from source: IndexSet, to destination: Int) {
        let previousItems = items
        var reorderedItems = items
        let movingItems = source.sorted().map { reorderedItems[$0] }

        for index in source.sorted(by: >) {
            reorderedItems.remove(at: index)
        }

        let adjustedDestination = destination - source.filter { $0 < destination }.count
        reorderedItems.insert(contentsOf: movingItems, at: adjustedDestination)
        items = reorderedItems

        Task {
            do {
                let updates = reorderedItems.enumerated().map { index, location in
                    (id: location.id, sortOrder: (index + 1) * 10)
                }
                try await repo.updateLocationSortOrders(updates)
                items = try await repo.fetchLocations()
                NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
            } catch {
                items = previousItems
                errorMessage = AppError.message(for: error)
            }
        }
    }

    func deleteLocation(locationId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let count = try await repo.countUnits(locationId: locationId)
            guard count == 0 else {
                errorMessage = count == 1
                    ? "Dieser Ort ist noch 1 Eintrag zugeordnet und kann nicht gelöscht werden."
                    : "Dieser Ort ist noch \(count) Einträgen zugeordnet und kann nicht gelöscht werden."
                return false
            }

            try await repo.deleteLocation(locationId: locationId)
            items = try await repo.fetchLocations()
            NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
            return true
        } catch {
            errorMessage = AppError.message(for: error)
            return false
        }
    }

    func countUnits(locationId: UUID) async -> Int? {
        do {
            return try await repo.countUnits(locationId: locationId)
        } catch {
            errorMessage = AppError.message(for: error)
            return nil
        }
    }

    private var nextSortOrder: Int {
        (items.compactMap(\.sort_order).max() ?? items.count * 10) + 10
    }
}
