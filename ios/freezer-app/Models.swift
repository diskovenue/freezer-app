//
//  Models.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//
import Foundation

struct UnitDisplayRow: Decodable, Identifiable {
    let id: UUID

    let product_ean: String?      // <-- neu/ wichtig für Gruppierung

    let display_name: String?
    let category_name: String?
    let category_emoji: String?

    let location_name: String?

    let due_date: String?
    let days_left: Int?
    let frozen_at: String?

    let attention_reason: String?
    let status: String?
}
