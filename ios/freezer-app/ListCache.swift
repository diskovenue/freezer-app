//
//  ListCache.swift
//  freezer-app
//
//  Created by OpenAI on 18.08.25.
//

import Foundation

enum ListCacheKey: String {
    case inventory = "cached_inventory_items"
    case attention = "cached_attention_items"
}

enum ListCache {
    static func load(_ key: ListCacheKey) -> [UnitDisplayRow] {
        guard
            let data = UserDefaults.standard.data(forKey: key.rawValue),
            let items = try? JSONDecoder().decode([UnitDisplayRow].self, from: data)
        else {
            return []
        }

        return items
    }

    static func save(_ items: [UnitDisplayRow], for key: ListCacheKey) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key.rawValue)
    }
}
