//
//  LoginView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroHeader
                    loginCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(background)
            .navigationBarHidden(true)
            .scrollDismissesKeyboard(.immediately)
            .onAppear { focus = .email }
            .alert("Anmeldung fehlgeschlagen", isPresented: authErrorIsPresented) {
                Button("OK", role: .cancel) {
                    auth.errorMessage = nil
                }
            } message: {
                Text(auth.errorMessage ?? "Bitte versuche es erneut.")
            }
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 10) {
            Text("Willkommen zurück")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)

            Text("Melde dich an und behalte deine eingefrorenen Vorräte im Blick.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Anmelden")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Deine Session bleibt auf diesem Gerät gespeichert.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                fieldBlock(title: "E-Mail", symbol: "at") {
                    TextField(
                        text: $email,
                        prompt: Text("E-Mail").foregroundStyle(.secondary)
                    ) {
                        EmptyView()
                    }
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                        .foregroundStyle(.primary)
                }

                fieldBlock(title: "Passwort", symbol: "lock") {
                    SecureField(
                        text: $password,
                        prompt: Text("Passwort").foregroundStyle(.secondary)
                    ) {
                        EmptyView()
                    }
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn() }
                        .foregroundStyle(.primary)
                }
            }

            Button { signIn() } label: {
                HStack(spacing: 10) {
                    Spacer()
                    if auth.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.semibold))
                        Text("Einloggen")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(buttonGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .disabled(auth.isLoading || email.isEmpty || password.isEmpty)
            .opacity(auth.isLoading || email.isEmpty || password.isEmpty ? 0.72 : 1)

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                Text("Anmeldedaten werden nur für deine gesicherte Session verwendet.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.92),
                Color.accentColor.opacity(0.76)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color(.systemBackground),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 20)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color.mint.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 24)
                .offset(x: 120, y: -180)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func fieldBlock<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            content()
                .fieldStyle()
        }
    }

    private func signIn() {
        Task {
            await auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }

    private var authErrorIsPresented: Binding<Bool> {
        Binding(
            get: { auth.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    auth.errorMessage = nil
                }
            }
        )
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .font(.body)
            .frame(height: 52)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}
