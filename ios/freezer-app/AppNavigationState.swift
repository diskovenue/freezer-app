//
//  AppNavigationState.swift
//  freezer-app
//
//  Created by OpenAI on 18.08.25.
//

import Foundation
import Combine

enum AppTab: Hashable {
    case inventory
    case scan
    case attention
    case settings
}

@MainActor
final class AppNavigationState: ObservableObject {
    static let shared = AppNavigationState()

    @Published var selectedTab: AppTab = .inventory

    private init() {}

    func openAttentionTab() {
        selectedTab = .attention
    }
}
