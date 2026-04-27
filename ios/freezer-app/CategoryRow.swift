//
//  CategoryRow.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import Foundation

struct CategoryRow: Decodable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String?
    let freezer_months: Int
    let sort_order: Int?
}
