import Foundation
import Supabase

struct ProfileRow: Codable, Identifiable {
    let id: UUID
    let display_name: String?
}

struct ProfileRepository {
    private let client: SupabaseClient = SupabaseConfig.client

    func fetchProfile() async throws -> ProfileRow? {
        let session = try await client.auth.session
        return try await fetchProfile(userId: session.user.id)
    }

    func fetchProfile(userId: UUID) async throws -> ProfileRow? {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select("id, display_name")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func upsertDisplayName(_ displayName: String?) async throws {
        let session = try await client.auth.session

        struct ProfileUpdate: Encodable {
            let id: UUID
            let display_name: String?
            let updated_at: String
        }

        let payload = ProfileUpdate(
            id: session.user.id,
            display_name: displayName,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        _ = try await client
            .from("profiles")
            .upsert(payload, onConflict: "id")
            .execute()
    }
}
