//
//  SupabaseService.swift
//  Polar Pill
//
//  Single shared Supabase client used by all view models / repositories.
//

import Foundation
import Supabase

@MainActor
final class SupabaseService {
    /// Shared instance. Nil until Config/Config.xcconfig contains real credentials,
    /// which lets the app show a friendly "not configured" screen instead of crashing.
    static let shared: SupabaseService? = {
        guard let url = AppConfig.supabaseURL, let key = AppConfig.supabaseAnonKey else {
            return nil
        }
        return SupabaseService(url: url, anonKey: key)
    }()

    let client: SupabaseClient

    private init(url: URL, anonKey: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }
}
