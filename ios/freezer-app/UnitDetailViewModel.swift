//
//  UnitDetailViewModel.swift
//  freezer-app
//
//  Created by Andreas Gößl on 27.04.26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class UnitDetailViewModel: ObservableObject {
    @Published var unit: FreezerUnit?
    @Published var displayUnit: UnitDisplayRow?
    @Published var isLoading = false
    @Published var isPhotoLoading = false
    @Published var isPhotoUpdating = false
    @Published var errorMessage: String?
    @Published var undoItem: UndoItem?
    @Published var photoImage: UIImage?
    @Published var creatorDisplayName: String?

    private let repo = InventoryRepository()
    private let profileRepo = ProfileRepository()
    private let unitId: UUID
    private let initialDisplayName: String?

    struct UndoItem: Identifiable {
        let id: UUID
        let title: String
    }

    init(unitId: UUID, initialDisplayName: String?) {
        self.unitId = unitId
        self.initialDisplayName = initialDisplayName
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let unitRequest = repo.fetchUnit(id: unitId)
            async let displayUnitRequest = repo.fetchUnitDisplay(id: unitId)
            let loadedUnit = try await unitRequest
            let loadedDisplayUnit = try await displayUnitRequest
            let loadedCreatorName: String?
            if let creatorID = loadedUnit.created_by {
                let profile = try? await profileRepo.fetchProfile(userId: creatorID)
                loadedCreatorName = profile?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            } else {
                loadedCreatorName = nil
            }

            let loadedPhoto: UIImage?
            if let path = loadedUnit.photo_path, !path.isEmpty {
                loadedPhoto = try? await UnitPhotoStore.shared.image(for: path)
            } else {
                loadedPhoto = nil
            }

            unit = loadedUnit
            displayUnit = loadedDisplayUnit
            creatorDisplayName = loadedCreatorName
            photoImage = loadedPhoto
        } catch {
            errorMessage = AppError.message(for: error)
        }
    }

    func consume() async throws {
        let photoPath = try await repo.consumeUnit(id: unitId)
        let title = unit?.name_override?.isEmpty == false ? unit?.name_override : nil

        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            undoItem = UndoItem(id: unitId, title: title ?? "Entnommen")
        }
        if let photoPath {
            PendingPhotoDeletionStore.shared.scheduleDeletion(for: unitId, path: photoPath)
        }
        notifyInventoryDataChanged()
        NotificationCenter.default.post(
            name: .unitDetailDidConsume,
            object: nil,
            userInfo: [
                AppNotificationKey.unitID: unitId,
                AppNotificationKey.title: title ?? "Entnommen"
            ]
        )

        let current = undoItem?.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.undoItem?.id == current {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.undoItem = nil
                }
            }
        }
    }

    func undoLastConsume() async throws {
        guard let undo = undoItem else { return }

        try await repo.restoreUnit(id: undo.id)
        PendingPhotoDeletionStore.shared.cancelDeletion(for: undo.id)
        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            undoItem = nil
        }
        notifyInventoryDataChanged()
    }

    func saveEdits(
        nameOverride: String?,
        frozenAt: String?,
        quantityValue: Int?,
        quantityUnit: String?,
        categoryId: UUID?,
        locationId: UUID,
        note: String?
    ) async throws {
        try await repo.updateUnit(
            id: unitId,
            nameOverride: nameOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            frozenAt: frozenAt,
            quantityValue: quantityValue,
            quantityUnit: quantityUnit,
            categoryId: categoryId,
            locationId: locationId,
            note: note
        )

        async let unitRequest = repo.fetchUnit(id: unitId)
        async let displayUnitRequest = repo.fetchUnitDisplay(id: unitId)
        let updatedUnit = try await unitRequest
        let updatedDisplayUnit = try await displayUnitRequest

        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            unit = updatedUnit
            displayUnit = updatedDisplayUnit
        }
        await loadPhotoIfNeeded(force: true)
        notifyInventoryDataChanged()
    }

    func setPhoto(_ image: UIImage) async throws {
        guard !isPhotoUpdating else { return }
        isPhotoUpdating = true
        defer { isPhotoUpdating = false }

        let previousPath = unit?.photo_path
        let newPath = try await UnitPhotoStore.shared.uploadImage(image, for: unitId)

        do {
            try await repo.updateUnitPhotoPath(id: unitId, photoPath: newPath)
        } catch {
            await UnitPhotoStore.shared.deleteImage(at: newPath)
            throw error
        }

        if let previousPath, previousPath != newPath {
            await UnitPhotoStore.shared.deleteImage(at: previousPath)
        }

        unit = try await repo.fetchUnit(id: unitId)
        photoImage = image
        notifyInventoryDataChanged()
    }

    func removePhoto() async throws {
        guard let photoPath = unit?.photo_path, !photoPath.isEmpty, !isPhotoUpdating else { return }
        isPhotoUpdating = true
        defer { isPhotoUpdating = false }

        try await repo.updateUnitPhotoPath(id: unitId, photoPath: nil)
        await UnitPhotoStore.shared.deleteImage(at: photoPath)
        unit = try await repo.fetchUnit(id: unitId)
        photoImage = nil
        notifyInventoryDataChanged()
    }

    func loadPhotoIfNeeded(force: Bool = false) async {
        guard let path = unit?.photo_path, !path.isEmpty else {
            photoImage = nil
            return
        }
        if photoImage != nil, !force {
            return
        }

        isPhotoLoading = true
        defer { isPhotoLoading = false }

        do {
            photoImage = try await UnitPhotoStore.shared.image(for: path)
        } catch {
            photoImage = nil
        }
    }

    private func notifyInventoryDataChanged() {
        NotificationCenter.default.post(name: .inventoryDataDidChange, object: nil)
    }

    var resolvedDisplayName: String? {
        preferredNameOverride ?? initialDisplayName
    }

    var editableName: String {
        preferredNameOverride ?? initialDisplayName ?? ""
    }

    var editableQuantityValue: String {
        if let quantityValue = unit?.quantity_value {
            return "\(quantityValue)"
        }
        if let weight = unit?.weight_g {
            return "\(weight)"
        }
        return ""
    }

    var editableQuantityUnit: String {
        unit?.quantity_unit ?? (unit?.weight_g != nil ? "g" : "g")
    }

    private var preferredNameOverride: String? {
        unit?.name_override?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
