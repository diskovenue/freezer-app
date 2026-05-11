import Foundation

struct CategorySuggestionMapper {
    private struct Rule {
        let categoryNames: [String]
        let tagFragments: [String]
    }

    private let rules: [Rule] = [
        Rule(
            categoryNames: ["Fleisch", "Wurst"],
            tagFragments: ["meat", "meats", "sausage", "sausages", "pork", "beef", "chicken", "poultry", "ham", "bacon", "fleisch", "wurst", "schinken", "geflugel", "huhn"]
        ),
        Rule(
            categoryNames: ["Fisch", "Meeresfrüchte", "Meeresfruechte"],
            tagFragments: ["fish", "seafood", "salmon", "tuna", "fisch", "lachs", "thunfisch", "meeresfruchte"]
        ),
        Rule(
            categoryNames: ["Gemüse", "Gemuese"],
            tagFragments: ["vegetable", "vegetables", "gemuse", "gemuese"]
        ),
        Rule(
            categoryNames: ["Obst", "Früchte", "Fruechte"],
            tagFragments: ["fruit", "fruits", "obst", "fruchte"]
        ),
        Rule(
            categoryNames: ["Brot", "Backwaren", "Brot & Backwaren"],
            tagFragments: ["bread", "bakery", "breads", "pastries", "brot", "backwaren"]
        ),
        Rule(
            categoryNames: ["Milchprodukte", "Milch", "Joghurt"],
            tagFragments: ["dairy", "milk", "yogurt", "yoghurt", "cream", "milch", "joghurt", "sahne"]
        ),
        Rule(
            categoryNames: ["Käse", "Kaese"],
            tagFragments: ["cheese", "kaese", "kase"]
        ),
        Rule(
            categoryNames: ["Eis"],
            tagFragments: ["ice-cream", "ice-creams", "sorbet", "speiseeis"]
        ),
        Rule(
            categoryNames: ["Fertiggerichte", "Fertiggericht", "Gerichte"],
            tagFragments: ["ready-meal", "ready-meals", "prepared-meals", "pizza", "pizzas", "meal", "meals", "fertiggericht"]
        ),
        Rule(
            categoryNames: ["Suppen", "Suppe"],
            tagFragments: ["soup", "soups", "suppe", "suppen"]
        ),
        Rule(
            categoryNames: ["Süßes", "Suesses", "Süßigkeiten", "Suessigkeiten"],
            tagFragments: ["sweet", "sweets", "chocolate", "dessert", "desserts", "candy", "suess", "suessigkeiten", "schokolade"]
        )
    ]

    func suggestedCategory(from tags: [String], in categories: [CategoryRow]) -> CategoryRow? {
        let normalizedTags = tags.map(normalize)
        guard !normalizedTags.isEmpty else { return nil }

        for rule in rules {
            guard normalizedTags.contains(where: { tag in
                rule.tagFragments.map(normalize).contains(where: tag.contains)
            }) else {
                continue
            }

            if let category = category(matching: rule.categoryNames, in: categories) {
                return category
            }
        }

        return nil
    }

    private func category(matching names: [String], in categories: [CategoryRow]) -> CategoryRow? {
        let normalizedNames = Set(names.map(normalize))
        return categories.first { normalizedNames.contains(normalize($0.name)) }
    }

    private func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "en:", with: "")
            .replacingOccurrences(of: "de:", with: "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
