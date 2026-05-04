import Foundation
import Supabase
import UIKit

@MainActor
final class UnitPhotoStore {
    static let shared = UnitPhotoStore()

    private let client = SupabaseConfig.client
    private let bucket = "photos"
    private var imageCache: [String: UIImage] = [:]

    func image(for path: String) async throws -> UIImage {
        if let cached = imageCache[path] {
            return cached
        }

        let data = try await client.storage
            .from(bucket)
            .download(path: path)

        guard let image = UIImage(data: data) else {
            throw NSError(
                domain: "UnitPhotoStore",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Foto konnte nicht geladen werden."]
            )
        }

        imageCache[path] = image
        return image
    }

    func uploadImage(_ image: UIImage, for unitID: UUID) async throws -> String {
        let preparedImage = image.preparedForUpload(maxDimension: 2200)
        guard let data = preparedImage.jpegData(compressionQuality: 0.82) else {
            throw NSError(
                domain: "UnitPhotoStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Foto konnte nicht verarbeitet werden."]
            )
        }

        let path = "units/\(unitID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

        try await client.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        imageCache[path] = preparedImage
        return path
    }

    func deleteImage(at path: String) async {
        do {
            try await client.storage
                .from(bucket)
                .remove(paths: [path])
        } catch {
        }

        imageCache.removeValue(forKey: path)
    }

    func replaceImage(
        _ image: UIImage,
        for unitID: UUID,
        previousPath: String?
    ) async throws -> String {
        let newPath = try await uploadImage(image, for: unitID)
        if let previousPath, previousPath != newPath {
            await deleteImage(at: previousPath)
        }
        return newPath
    }

    func clearCache(for path: String?) {
        guard let path else { return }
        imageCache.removeValue(forKey: path)
    }
}

private extension UIImage {
    func preparedForUpload(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scaleRatio = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
