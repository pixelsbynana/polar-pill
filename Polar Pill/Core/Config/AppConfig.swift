//
//  AppConfig.swift
//  Polar Pill
//
//  Reads build-time configuration injected from Config/Config.xcconfig
//  into Info.plist. Keys are never hardcoded in source.
//

import Foundation

enum AppConfig {
    /// Supabase project URL from Config.xcconfig, or nil if not yet configured.
    static var supabaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              !raw.isEmpty,
              !raw.contains("YOUR-PROJECT-REF"),
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }

    /// Supabase anon (public) key from Config.xcconfig, or nil if not yet configured.
    static var supabaseAnonKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !raw.isEmpty,
              !raw.contains("YOUR-SUPABASE-ANON-KEY") else {
            return nil
        }
        return raw
    }

    /// True once real Supabase credentials have been filled into Config.xcconfig.
    static var isConfigured: Bool {
        supabaseURL != nil && supabaseAnonKey != nil
    }
}
