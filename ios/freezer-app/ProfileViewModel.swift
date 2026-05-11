import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    private let repo = ProfileRepository()
    private var originalDisplayName = ""

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let profile = try await repo.fetchProfile()
            displayName = profile?.display_name ?? ""
            originalDisplayName = displayName
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func saveIfNeeded() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName != originalDisplayName else { return }
        await save()
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        didSave = false
        defer { isSaving = false }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await repo.upsertDisplayName(trimmedName.isEmpty ? nil : trimmedName)
            displayName = trimmedName
            originalDisplayName = trimmedName
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }
}
