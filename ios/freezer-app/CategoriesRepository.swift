//
//  CategoriesRepository.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import Foundation
import Supabase

struct CategoriesRepository {
    private let client: SupabaseClient = SupabaseConfig.client
    private let fallbackCategoryName = "Sonstiges"
    private let deprecatedFallbackCategoryName = "Sonstige"

    func fetchCategories() async throws -> [CategoryRow] {
        let rows: [CategoryRow] = try await client
            .from("categories")
            .select("id, name, emoji, freezer_months, sort_order")
            .order("sort_order", ascending: true)
            .order("name", ascending: true)
            .execute()
            .value
        return rows
    }

    func fetchCategoriesNormalizingFallback() async throws -> [CategoryRow] {
        try await normalizeDeprecatedFallbackCategoryIfNeeded()
        return try await fetchCategories()
    }

    func updateFreezerMonths(categoryId: UUID, months: Int) async throws {
        struct Update: Encodable { let freezer_months: Int }
        _ = try await client
            .from("categories")
            .update(Update(freezer_months: months))
            .eq("id", value: categoryId.uuidString)
            .execute()
    }

    func createCategory(name: String, emoji: String?, freezerMonths: Int, sortOrder: Int?) async throws {
        struct Insert: Encodable {
            let name: String
            let emoji: String?
            let freezer_months: Int
            let sort_order: Int?
        }

        _ = try await client
            .from("categories")
            .insert(Insert(
                name: name,
                emoji: emoji,
                freezer_months: freezerMonths,
                sort_order: sortOrder
            ))
            .execute()
    }

    func updateCategory(categoryId: UUID, name: String, emoji: String?, freezerMonths: Int) async throws {
        struct Update: Encodable {
            let name: String
            let emoji: String?
            let freezer_months: Int
        }

        _ = try await client
            .from("categories")
            .update(Update(
                name: name,
                emoji: emoji,
                freezer_months: freezerMonths
            ))
            .eq("id", value: categoryId.uuidString)
            .execute()
    }

    func deleteCategory(categoryId: UUID) async throws {
        _ = try await client
            .from("categories")
            .delete()
            .eq("id", value: categoryId.uuidString)
            .execute()
    }

    func countUnits(categoryId: UUID) async throws -> Int {
        struct UnitIDRow: Decodable {
            let id: UUID
        }

        let rows: [UnitIDRow] = try await client
            .from("freezer_units")
            .select("id")
            .eq("category_id", value: categoryId.uuidString)
            .execute()
            .value

        return rows.count
    }

    func updateCategorySortOrders(_ updates: [(id: UUID, sortOrder: Int)]) async throws {
        struct Update: Encodable {
            let sort_order: Int
        }

        for update in updates {
            _ = try await client
                .from("categories")
                .update(Update(sort_order: update.sortOrder))
                .eq("id", value: update.id.uuidString)
                .execute()
        }
    }

    func deleteCategoryMovingUnitsToFallback(categoryId: UUID) async throws {
        let fallbackCategory = try await ensureFallbackCategory()

        guard fallbackCategory.id != categoryId else {
            throw NSError(
                domain: "Categories",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Die Kategorie \"\(fallbackCategoryName)\" kann nicht gelöscht werden."]
            )
        }

        try await moveUnits(from: categoryId, to: fallbackCategory.id)
        try await deleteCategory(categoryId: categoryId)
    }

    private func ensureFallbackCategory() async throws -> CategoryRow {
        try await normalizeDeprecatedFallbackCategoryIfNeeded()

        let categories = try await fetchCategories()
        if let fallback = categories.first(where: { $0.name.localizedCaseInsensitiveCompare(fallbackCategoryName) == .orderedSame }) {
            return fallback
        }

        let nextSortOrder = ((categories.compactMap(\.sort_order).max() ?? categories.count * 10) + 10)
        try await createCategory(name: fallbackCategoryName, emoji: "📦", freezerMonths: 6, sortOrder: nextSortOrder)

        let updatedCategories = try await fetchCategories()
        if let fallback = updatedCategories.first(where: { $0.name.localizedCaseInsensitiveCompare(fallbackCategoryName) == .orderedSame }) {
            return fallback
        }

        throw NSError(
            domain: "Categories",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Die Kategorie \"\(fallbackCategoryName)\" konnte nicht angelegt werden."]
        )
    }

    private func normalizeDeprecatedFallbackCategoryIfNeeded() async throws {
        let categories = try await fetchCategories()
        let canonical = categories.first {
            $0.name.localizedCaseInsensitiveCompare(fallbackCategoryName) == .orderedSame
        }
        let deprecated = categories.first {
            $0.name.localizedCaseInsensitiveCompare(deprecatedFallbackCategoryName) == .orderedSame
        }

        guard let deprecated else { return }

        if let canonical {
            guard canonical.id != deprecated.id else { return }
            try await moveUnits(from: deprecated.id, to: canonical.id)
            try await deleteCategory(categoryId: deprecated.id)
            return
        }

        try await updateCategory(
            categoryId: deprecated.id,
            name: fallbackCategoryName,
            emoji: deprecated.emoji,
            freezerMonths: deprecated.freezer_months
        )
    }

    private func moveUnits(from sourceCategoryId: UUID, to targetCategoryId: UUID) async throws {
        struct UnitUpdate: Encodable {
            let category_id: UUID
        }

        _ = try await client
            .from("freezer_units")
            .update(UnitUpdate(category_id: targetCategoryId))
            .eq("category_id", value: sourceCategoryId.uuidString)
            .execute()
    }
}
