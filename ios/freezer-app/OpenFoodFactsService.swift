import Foundation
import UIKit

struct OpenFoodFactsService {
    struct ProductDraft {
        let name: String?
        let image: UIImage?
    }

    private struct Response: Decodable {
        let status: Int?
        let product: Product?
    }

    private struct Product: Decodable {
        let product_name: String?
        let product_name_de: String?
        let product_name_en: String?
        let image_front_url: String?
        let image_url: String?
    }

    func fetchProduct(barcode: String) async throws -> ProductDraft? {
        guard let url = URL(string: "https://world.openfoodfacts.net/api/v2/product/\(barcode)?fields=product_name,product_name_de,product_name_en,image_front_url,image_url") else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)

        guard response.status == 1, let product = response.product else {
            return nil
        }

        let name = preferredName(from: product)
        let image = try await loadImage(from: product.image_front_url ?? product.image_url)
        return ProductDraft(name: name, image: image)
    }

    private func preferredName(from product: Product) -> String? {
        let candidates = [
            product.product_name_de,
            product.product_name,
            product.product_name_en
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private func loadImage(from urlString: String?) async throws -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
}
