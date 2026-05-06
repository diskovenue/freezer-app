//
//  freezer_appApp.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI
import Auth

@main
struct freezer_appApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthViewModel()
    @StateObject private var settings = AppSettings()
    @StateObject private var navigation = AppNavigationState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(settings)
                .environmentObject(navigation)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var navigation: AppNavigationState

    var body: some View {
        ZStack {
            if !auth.hasLoadedSession {
                launchLoadingView
                    .transition(rootTransition)
            } else if auth.session == nil {
                LoginView()
                    .transition(rootTransition)
            } else {
                MainTabView()
                    .transition(rootTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.28), value: auth.hasLoadedSession)
        .animation(.easeInOut(duration: 0.28), value: auth.session != nil)
        .task {
            await auth.loadSession()
            if auth.session != nil {
                navigation.consumePreferredLaunchTabIfNeeded()
                navigation.resetToDefaultTabIfNeeded()
            }
            await PushRegistration.syncStoredTokenIfPossible()
        }
        .onChange(of: auth.session?.user.id) { _, newValue in
            guard newValue != nil else { return }
            navigation.consumePreferredLaunchTabIfNeeded()
            navigation.resetToDefaultTabIfNeeded()
            Task {
                await PushRegistration.syncStoredTokenIfPossible()
            }
        }
    }

    private var launchLoadingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ProgressView()
                .controlSize(.large)
        }
    }

    private var rootTransition: AnyTransition {
        .opacity
    }
}
