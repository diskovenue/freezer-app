//
//  SupabaseConfig.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: Secrets.string("SUPABASE_URL"))!
    static let anonKey = Secrets.string("SUPABASE_ANON_KEY")

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
