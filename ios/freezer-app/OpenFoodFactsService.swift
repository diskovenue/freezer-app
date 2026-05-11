import Foundation
import UIKit

struct OpenFoodFactsService {
    struct ProductDraft {
        let name: String?
        let image: UIImage?
        let categoryTags: [String]
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
        let categories_tags: [String]?
        let categories_hierarchy: [String]?
        let food_groups_tags: [String]?
    }

    func fetchProduct(barcode: String) async throws -> ProductDraft? {
        guard let url = URL(string: "https://world.openfoodfacts.net/api/v2/product/\(barcode)?fields=product_name,product_name_de,product_name_en,image_front_url,image_url,categories_tags,categories_hierarchy,food_groups_tags") else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)

        guard response.status == 1, let product = response.product else {
            return nil
        }

        let name = preferredName(from: product)
        let image = try await loadImage(from: product.image_front_url ?? product.image_url)
        return ProductDraft(
            name: name,
            image: image,
            categoryTags: categoryTags(from: product)
        )
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

    private func categoryTags(from product: Product) -> [String] {
        var seen = Set<String>()
        return [
            product.food_groups_tags,
            product.categories_tags,
            product.categories_hierarchy
        ]
        .compactMap { $0 }
        .flatMap { $0 }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .filter { seen.insert($0).inserted }
    }
}
