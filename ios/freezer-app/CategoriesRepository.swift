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

    func updateFreezerMonths(categoryId: UUID, months: Int) async throws {
        struct Update: Encodable { let freezer_months: Int }
        _ = try await client
            .from("categories")
            .update(Update(freezer_months: months))
            .eq("id", value: categoryId.uuidString)
            .execute()
    }
}
