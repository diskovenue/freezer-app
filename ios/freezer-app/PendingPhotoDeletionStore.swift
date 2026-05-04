import Foundation

@MainActor
final class PendingPhotoDeletionStore {
    static let shared = PendingPhotoDeletionStore()

    private var tasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func scheduleDeletion(for unitID: UUID, path: String, delayNanoseconds: UInt64 = 5_000_000_000) {
        cancelDeletion(for: unitID)

        tasks[unitID] = Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            await UnitPhotoStore.shared.deleteImage(at: path)
            await MainActor.run {
                self.tasks[unitID] = nil
            }
        }
    }

    func cancelDeletion(for unitID: UUID) {
        tasks[unitID]?.cancel()
        tasks[unitID] = nil
    }
}
