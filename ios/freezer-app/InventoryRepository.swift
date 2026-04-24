//
//  InventoryRepository.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import Foundation
import Supabase

struct InventoryRepository {
    private let client: SupabaseClient = SupabaseConfig.client

    // MARK: - Fetch (active inventory)
    func fetchUnitsDisplay() async throws -> [UnitDisplayRow] {
        let rows: [UnitDisplayRow] = try await client
            .from("v_units_display")
            .select("""
                id,
                product_ean,
                display_name,
                category_name,
                category_emoji,
                location_name,
                due_date,
                days_left,
                attention_reason,
                status
            """)
            .eq("status", value: "active")
            .order("days_left", ascending: true)
            .execute()
            .value

        return rows
    }

    // MARK: - Fetch (attention list)
    func fetchAttention() async throws -> [UnitDisplayRow] {
        let rows: [UnitDisplayRow] = try await client
            .from("v_units_display")
            .select("""
                id,
                product_ean,
                display_name,
                category_name,
                category_emoji,
                location_name,
                due_date,
                days_left,
                attention_reason,
                status
            """)
            .eq("status", value: "active")
            .`in`("attention_reason", values: ["mhd_2", "mhd_7"])
            .order("days_left", ascending: true)
            .execute()
            .value

        return rows
    }

    // MARK: - Mutations
    func consumeUnit(id: UUID) async throws {
        struct Update: Encodable {
            let status: String
            let consumed_at: String
        }

        let iso = ISO8601DateFormatter().string(from: Date())

        _ = try await client
            .from("freezer_units")
            .update(Update(status: "consumed", consumed_at: iso))
            .eq("id", value: id.uuidString)
            .execute()
    }
}
