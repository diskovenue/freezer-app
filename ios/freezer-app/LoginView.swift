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
            VStack(spacing: 18) {
                header

                VStack(spacing: 12) {
                    TextField("E-Mail", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                        .fieldStyle()

                    SecureField("Passwort", text: $password)
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn() }
                        .fieldStyle()
                }
                .padding(.top, 6)

                if let msg = auth.errorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                Button { signIn() } label: {
                    HStack {
                        Spacer()
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Einloggen").font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(auth.isLoading || email.isEmpty || password.isEmpty)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .background(background)
            .navigationBarHidden(true)
            .onAppear { focus = .email }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.thinMaterial)
                    Image(systemName: "snowflake")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 44, height: 44)

                Text("Gefrierliste")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Text("Einloggen, um deinen Bestand zu verwalten.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.10),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    private func signIn() {
        Task {
            await auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
