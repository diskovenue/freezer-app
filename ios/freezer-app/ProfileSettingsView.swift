import SwiftUI

struct ProfileSettingsView: View {
    let email: String?

    @StateObject private var vm = ProfileViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case displayName
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    text: $vm.displayName,
                    prompt: Text("Anzeigename")
                ) {
                    EmptyView()
                }
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .displayName)

                if let email, !email.isEmpty {
                    LabeledContent("E-Mail", value: email)
                }
            } header: {
                Text("Profil")
            } footer: {
                Text("Der Anzeigename wird für dein Profil verwendet. Deine Login-E-Mail bleibt unverändert.")
            }

        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .onDisappear {
            Task { await vm.saveIfNeeded() }
        }
        .alert("Profil konnte nicht geladen werden", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {
                vm.errorMessage = nil
            }
        } message: {
            Text(vm.errorMessage ?? "Bitte versuche es erneut.")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    vm.errorMessage = nil
                }
            }
        )
    }
}
