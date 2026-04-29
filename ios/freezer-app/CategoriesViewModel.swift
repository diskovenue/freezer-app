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
            items = try await repo.fetchCategories()
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
}
