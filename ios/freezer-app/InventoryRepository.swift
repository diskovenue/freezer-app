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

    private struct PhotoPathRow: Decodable {
        let photo_path: String?
    }

    private struct CodeLookupRow: Decodable {
        let id: UUID
        let code_type: String
        let status: String?
        let consumed_at: String?
    }

    private struct InsertedIDRow: Decodable {
        let id: UUID
    }

    private struct ProductKeyInsert: Encodable {
        let ean: String
        let name: String
    }

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
                category_sort_order,
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
                category_sort_order,
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
    func consumeUnit(id: UUID) async throws -> String? {
        struct Update: Encodable {
            let status: String
            let consumed_at: String
        }

        let iso = ISO8601DateFormatter().string(from: Date())
        let photoPath = try await fetchPhotoPath(id: id)

        _ = try await client
            .from("freezer_units")
            .update(Update(status: "consumed", consumed_at: iso))
            .eq("id", value: id.uuidString)
            .execute()

        return photoPath
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

    func fetchPhotoPath(id: UUID) async throws -> String? {
        let rows: [PhotoPathRow] = try await client
            .from("freezer_units")
            .select("photo_path")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first?.photo_path
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
                quantity_value,
                quantity_unit,
                note,
                photo_path,
                status,
                consumed_at,
                created_by,
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

    func fetchUnitDisplay(id: UUID) async throws -> UnitDisplayRow {
        let rows: [UnitDisplayRow] = try await client
            .from("v_units_display")
            .select("""
                id,
                product_ean,
                display_name,
                category_name,
                category_emoji,
                category_sort_order,
                location_name,
                frozen_at,
                due_date,
                days_left,
                attention_reason,
                status
            """)
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let first = rows.first else {
            throw NSError(
                domain: "UnitDetailDisplay",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Anzeigeeintrag nicht gefunden"]
            )
        }
        return first
    }
    
    func updateUnit(
        id: UUID,
        nameOverride: String?,
        frozenAt: String?,
        quantityValue: Int?,
        quantityUnit: String?,
        categoryId: UUID?,
        locationId: UUID,
        note: String?
    ) async throws {
        struct Update: Encodable {
            let name_override: String?
            let frozen_at: String?
            let weight_g: Int?
            let quantity_value: Int?
            let quantity_unit: String?
            let category_id: UUID?
            let location_id: UUID
            let note: String?
        }

        _ = try await client
            .from("freezer_units")
            .update(Update(
                name_override: nameOverride,
                frozen_at: frozenAt,
                weight_g: quantityUnit == "g" ? quantityValue : nil,
                quantity_value: quantityValue,
                quantity_unit: quantityUnit,
                category_id: categoryId,
                location_id: locationId,
                note: note
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateUnitPhotoPath(id: UUID, photoPath: String?) async throws {
        struct Update: Encodable {
            let photo_path: String?
        }

        _ = try await client
            .from("freezer_units")
            .update(Update(photo_path: photoPath))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func fetchActiveCode128Unit(codeValue: String) async throws -> UnitDisplayRow? {
        let rows: [CodeLookupRow] = try await client
            .from("freezer_units")
            .select("id, code_type, status, consumed_at")
            .eq("status", value: "active")
            .eq("code_value", value: codeValue)
            .execute()
            .value

        guard let match = rows.first(where: { $0.code_type.uppercased().contains("128") }) else {
            return nil
        }

        return try await fetchUnitDisplay(id: match.id)
    }

    func fetchReusableCode128UnitID(codeValue: String) async throws -> UUID? {
        let rows: [CodeLookupRow] = try await client
            .from("freezer_units")
            .select("id, code_type, status, consumed_at")
            .eq("code_value", value: codeValue)
            .order("consumed_at", ascending: false)
            .execute()
            .value

        return rows.first(where: {
            $0.code_type.uppercased().contains("128") && ($0.status?.lowercased() != "active")
        })?.id
    }

    func createCode128Unit(
        codeValue: String,
        reusingUnitID: UUID?,
        nameOverride: String?,
        frozenAt: String?,
        quantityValue: Int?,
        quantityUnit: String?,
        categoryId: UUID?,
        locationId: UUID,
        note: String?
    ) async throws -> UUID {
        if let reusingUnitID {
            struct Reactivate: Encodable {
                let code_type: String
                let code_value: String
                let product_ean: String?
                let name_override: String?
                let category_id: UUID?
                let location_id: UUID
                let frozen_at: String?
                let best_before: String?
                let weight_g: Int?
                let quantity_value: Int?
                let quantity_unit: String?
                let note: String?
                let photo_path: String?
                let status: String
                let consumed_at: String?
                let attention_reason: String?
                let attention_since: String?
                let created_by: UUID?
            }

            let session = try await client.auth.session
            _ = try await client
                .from("freezer_units")
                .update(
                    Reactivate(
                        code_type: "CODE128",
                        code_value: codeValue,
                        product_ean: nil,
                        name_override: nameOverride,
                        category_id: categoryId,
                        location_id: locationId,
                        frozen_at: frozenAt,
                        best_before: nil,
                        weight_g: quantityUnit == "g" ? quantityValue : nil,
                        quantity_value: quantityValue,
                        quantity_unit: quantityUnit,
                        note: note,
                        photo_path: nil,
                        status: "active",
                        consumed_at: nil,
                        attention_reason: nil,
                        attention_since: nil,
                        created_by: session.user.id
                    )
                )
                .eq("id", value: reusingUnitID.uuidString)
                .execute()

            return reusingUnitID
        }

        struct Insert: Encodable {
            let code_type: String
            let code_value: String
            let product_ean: String?
            let name_override: String?
            let category_id: UUID?
            let location_id: UUID
            let frozen_at: String?
            let weight_g: Int?
            let quantity_value: Int?
            let quantity_unit: String?
            let note: String?
            let status: String
            let created_by: UUID
        }

        let session = try await client.auth.session
        let rows: [InsertedIDRow] = try await client
            .from("freezer_units")
            .insert(
                Insert(
                    code_type: "CODE128",
                    code_value: codeValue,
                    product_ean: nil,
                    name_override: nameOverride,
                    category_id: categoryId,
                    location_id: locationId,
                    frozen_at: frozenAt,
                    weight_g: quantityUnit == "g" ? quantityValue : nil,
                    quantity_value: quantityValue,
                    quantity_unit: quantityUnit,
                    note: note,
                    status: "active",
                    created_by: session.user.id
                )
            )
            .select("id")
            .execute()
            .value

        guard let id = rows.first?.id else {
            throw NSError(
                domain: "CreateUnit",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Der neue Eintrag konnte nicht angelegt werden."]
            )
        }

        return id
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

    func createEANUnit(
        ean: String,
        nameOverride: String?,
        frozenAt: String?,
        quantityValue: Int?,
        quantityUnit: String?,
        categoryId: UUID?,
        locationId: UUID,
        note: String?
    ) async throws -> UUID {
        let trimmedName = nameOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let productName = trimmedName.isEmpty ? ean : trimmedName
        try await ensureProductExists(ean: ean, name: productName)

        struct Insert: Encodable {
            let code_type: String
            let code_value: String
            let product_ean: String
            let name_override: String?
            let category_id: UUID?
            let location_id: UUID
            let frozen_at: String?
            let weight_g: Int?
            let quantity_value: Int?
            let quantity_unit: String?
            let note: String?
            let status: String
            let created_by: UUID
        }

        let session = try await client.auth.session
        let rows: [InsertedIDRow] = try await client
            .from("freezer_units")
            .insert(
                Insert(
                    code_type: "EAN",
                    code_value: ean,
                    product_ean: ean,
                    name_override: nameOverride,
                    category_id: categoryId,
                    location_id: locationId,
                    frozen_at: frozenAt,
                    weight_g: quantityUnit == "g" ? quantityValue : nil,
                    quantity_value: quantityValue,
                    quantity_unit: quantityUnit,
                    note: note,
                    status: "active",
                    created_by: session.user.id
                )
            )
            .select("id")
            .execute()
            .value

        guard let id = rows.first?.id else {
            throw NSError(
                domain: "CreateEANUnit",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Der neue Eintrag konnte nicht angelegt werden."]
            )
        }

        return id
    }

    private func ensureProductExists(ean: String, name: String) async throws {
        _ = try await client
            .from("products")
            .upsert(
                ProductKeyInsert(ean: ean, name: name),
                onConflict: "ean",
                ignoreDuplicates: true
            )
            .execute()
    }
}
