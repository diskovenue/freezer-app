//
//  Secrets.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//
import Foundation

enum Secrets {
    static func string(_ key: String) -> String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let value = dict[key] as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            fatalError("Missing Secrets.plist key: \(key)")
        }
        return value
    }
}
