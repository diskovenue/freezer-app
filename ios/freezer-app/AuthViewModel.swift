//
//  AuthViewModel.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import Foundation
import Supabase
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var hasLoadedSession = false
    @Published var session: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseConfig.client

    func loadSession() async {
        guard !hasLoadedSession else { return }

        do {
            session = try await client.auth.session
        } catch {
            // keine Session ist ok → bleibt nil
            session = nil
        }

        hasLoadedSession = true
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await client.auth.signIn(email: email, password: password)
            // Session danach direkt aus dem Client holen:
            session = try await client.auth.session
            hasLoadedSession = true
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func signOut() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.auth.signOut()
            session = nil
            hasLoadedSession = true
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }
}
