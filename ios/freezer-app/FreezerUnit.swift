//
//  FreezerUnit.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import Foundation

struct FreezerUnit: Decodable, Identifiable {
    let id: UUID

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
    let created_by: UUID?

    let attention_reason: String?
    let attention_since: String?
}
