//
//  CategoriesViewModel.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import Foundation
import Combine

@MainActor
final class CategoriesViewModel: ObservableObject {
    @Published var items: [CategoryRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = CategoriesRepository()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await repo.fetchCategoriesNormalizingFallback()
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func updateMonths(categoryId: UUID, months: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.updateFreezerMonths(categoryId: categoryId, months: months)
            items = try await repo.fetchCategories()
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func saveCategory(
        categoryId: UUID?,
        name: String,
        emoji: String?,
        freezerMonths: Int
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let categoryId {
                try await repo.updateCategory(
                    categoryId: categoryId,
                    name: name,
                    emoji: emoji,
                    freezerMonths: freezerMonths
                )
            } else {
                try await repo.createCategory(
                    name: name,
                    emoji: emoji,
                    freezerMonths: freezerMonths,
                    sortOrder: nextSortOrder
                )
            }
            items = try await repo.fetchCategories()
            return true
        } catch {
            errorMessage = AppError.message(for: error)
            return false
        }
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
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
                let updates = reorderedItems.enumerated().map { index, category in
                    (id: category.id, sortOrder: (index + 1) * 10)
                }
                try await repo.updateCategorySortOrders(updates)
                items = try await repo.fetchCategories()
                NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
            } catch {
                items = previousItems
                errorMessage = AppError.message(for: error)
            }
        }
    }

    func deleteCategories(at offsets: IndexSet) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            for index in offsets {
                try await repo.deleteCategory(categoryId: items[index].id)
            }
            items = try await repo.fetchCategories()
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func deleteCategory(categoryId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await repo.deleteCategoryMovingUnitsToFallback(categoryId: categoryId)
            items = try await repo.fetchCategories()
            NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
            return true
        } catch {
            errorMessage = AppError.message(for: error)
            return false
        }
    }

    func countUnits(categoryId: UUID) async -> Int? {
        do {
            return try await repo.countUnits(categoryId: categoryId)
        } catch {
            errorMessage = AppError.message(for: error)
            return nil
        }
    }

    private var nextSortOrder: Int {
        (items.compactMap(\.sort_order).max() ?? items.count * 10) + 10
    }
}
