//
//  AppSettings.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: key) }
    }

    private let key = "app.appearance"

    init() {
        let raw = UserDefaults.standard.string(forKey: key) ?? AppAppearance.system.rawValue
        self.appearance = AppAppearance(rawValue: raw) ?? .system
    }
}
