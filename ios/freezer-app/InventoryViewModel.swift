//
//  InventoryViewModel.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import Foundation
import Combine

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var items: [UnitDisplayRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = InventoryRepository()

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
}
