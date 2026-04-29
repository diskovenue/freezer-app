import Foundation
import Supabase

struct LocationsRepository {
    private let client: SupabaseClient = SupabaseConfig.client

    func fetchLocations() async throws -> [LocationRow] {
        let rows: [LocationRow] = try await client
            .from("locations")
            .select("id, name, sort_order")
            .order("sort_order", ascending: true)
            .order("name", ascending: true)
            .execute()
            .value
        return rows
    }
}
