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
    private var preferredLaunchTab: AppTab?

    private init() {}

    func openAttentionTab() {
        preferredLaunchTab = .attention
        selectedTab = .attention
    }

    func selectInitialTab() {
        if let preferredLaunchTab {
            selectedTab = preferredLaunchTab
            self.preferredLaunchTab = nil
        } else {
            selectedTab = .inventory
        }
    }
}
