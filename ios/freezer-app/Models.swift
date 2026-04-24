//
//  Models.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//
import Foundation

struct UnitDisplayRow: Decodable, Identifiable {
    let id: UUID

    let display_name: String?
    let category_name: String?
    let category_emoji: String?

    let location_name: String?

    let due_date: String?      // ISO date "YYYY-MM-DD"
    let days_left: Int?

    let attention_reason: String?
    let status: String?
}
