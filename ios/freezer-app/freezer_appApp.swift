//
//  freezer_appApp.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

@main
struct FreezerApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .task {
                    await auth.loadSession()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if auth.session == nil {
            LoginView()
        } else {
            // Platzhalter – hier kommen später Tabs rein
            Text("Eingeloggt!")
        }
    }
}
