import Foundation

struct LocationRow: Decodable, Identifiable {
    let id: UUID
    let name: String
    let sort_order: Int?
}
