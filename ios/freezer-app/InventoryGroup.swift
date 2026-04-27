//
//  InventoryGroup.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import Foundation

struct InventoryGroup: Identifiable {
    let id: String
    let title: String
    let categoryKey: String
    let categoryName: String?
    let categoryEmoji: String?
    let categorySortOrder: Int?
    let locationName: String?

    let minDaysLeft: Int?
    let minFrozenAtISO: String?   // <- so muss es heißen

    let count: Int
    let items: [UnitDisplayRow]

    var minFrozenAtFormatted: String? {
        guard let iso = minFrozenAtISO else { return nil }
        return Self.formatISODate(iso)
    }

    private static func formatISODate(_ iso: String) -> String {
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"

        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "de_DE")
        outFmt.dateFormat = "dd.MM.yy"

        guard let d = inFmt.date(from: iso) else { return iso }
        return outFmt.string(from: d)
    }
}
