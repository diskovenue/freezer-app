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

    func createLocation(name: String, sortOrder: Int?) async throws {
        struct Insert: Encodable {
            let name: String
            let sort_order: Int?
        }

        _ = try await client
            .from("locations")
            .insert(Insert(name: name, sort_order: sortOrder))
            .execute()
    }

    func updateLocation(locationId: UUID, name: String) async throws {
        struct Update: Encodable {
            let name: String
        }

        _ = try await client
            .from("locations")
            .update(Update(name: name))
            .eq("id", value: locationId.uuidString)
            .execute()
    }

    func deleteLocation(locationId: UUID) async throws {
        _ = try await client
            .from("locations")
            .delete()
            .eq("id", value: locationId.uuidString)
            .execute()
    }

    func countUnits(locationId: UUID) async throws -> Int {
        struct UnitIDRow: Decodable {
            let id: UUID
        }

        let rows: [UnitIDRow] = try await client
            .from("freezer_units")
            .select("id")
            .eq("location_id", value: locationId.uuidString)
            .execute()
            .value

        return rows.count
    }

    func updateLocationSortOrders(_ updates: [(id: UUID, sortOrder: Int)]) async throws {
        struct Update: Encodable {
            let sort_order: Int
        }

        for update in updates {
            _ = try await client
                .from("locations")
                .update(Update(sort_order: update.sortOrder))
                .eq("id", value: update.id.uuidString)
                .execute()
        }
    }
}
