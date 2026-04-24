//
//  InventoryRepository.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import Foundation
import Supabase

struct InventoryRepository {
    private let client = SupabaseConfig.client

    func fetchUnitsDisplay() async throws -> [UnitDisplayRow] {
        let rows: [UnitDisplayRow] = try await client
            .from("v_units_display")
            .select("""
                id,
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
    
    func fetchAttention() async throws -> [UnitDisplayRow] {
        let rows: [UnitDisplayRow] = try await client
            .from("v_units_display")
            .select("""
                id,
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
            .in("attention_reason", values: ["mhd_2", "mhd_7"])
            .order("days_left", ascending: true)
            .execute()
            .value

        return rows
    }
}
