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
                frozen_at,
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
                frozen_at,
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
    
    func restoreUnit(id: UUID) async throws {
        struct Update: Encodable {
            let status: String
            let consumed_at: String?
            let attention_reason: String?
            let attention_since: String?
        }

        _ = try await client
            .from("freezer_units")
            .update(Update(
                status: "active",
                consumed_at: nil,
                attention_reason: nil,
                attention_since: nil
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func fetchUnit(id: UUID) async throws -> FreezerUnit {
        let rows: [FreezerUnit] = try await client
            .from("freezer_units")
            .select("""
                id,
                code_type,
                code_value,
                product_ean,
                name_override,
                category_id,
                location_id,
                frozen_at,
                best_before,
                weight_g,
                note,
                photo_path,
                status,
                consumed_at,
                attention_reason,
                attention_since
            """)
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let first = rows.first else {
            throw NSError(
                domain: "UnitDetail",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Eintrag nicht gefunden"]
            )
        }
        return first
    }
    
    func updateUnit(
        id: UUID,
        nameOverride: String?,
        frozenAt: String?,
        weightG: Int?,
        note: String?
    ) async throws {
        struct Update: Encodable {
            let name_override: String?
            let frozen_at: String?
            let weight_g: Int?
            let note: String?
        }

        _ = try await client
            .from("freezer_units")
            .update(Update(
                name_override: nameOverride,
                frozen_at: frozenAt,
                weight_g: weightG,
                note: note
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func fetchUnitsByEAN(_ ean: String) async throws -> [UnitDisplayRow] {
        let rows: [UnitDisplayRow] = try await client
            .from("v_units_display")
            .select("""
                id,
                product_ean,
                display_name,
                category_name,
                category_emoji,
                location_name,
                frozen_at,
                due_date,
                days_left,
                attention_reason,
                status
            """)
            .eq("status", value: "active")
            .eq("product_ean", value: ean)
            .order("days_left", ascending: true)
            .execute()
            .value

        return rows
    }
}
