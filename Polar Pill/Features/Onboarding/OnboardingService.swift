//
//  OnboardingService.swift
//  Polar Pill
//
//  Persists the onboarding draft (role + family members) to Supabase after
//  the user authenticates. Family creation must happen post-auth because
//  RLS requires created_by = auth.uid().
//

import Foundation
import Supabase

/// A family member added during onboarding, before anything exists server-side.
struct DraftFamilyMember: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var email: String = ""
    var phone: String = ""
    var isRemote: Bool = true
}

struct OnboardingService {
    let client: SupabaseClient

    private struct FamilyInsert: Encodable {
        let name: String
        let created_by: UUID
    }

    private struct MemberInsert: Encodable {
        let family_id: UUID
        let profile_id: UUID?
        let relationship_label: String
        let is_remote: Bool
        let invite_email: String?
        let phone: String?
    }

    /// Creates the family, a member row for the current user, and invite rows
    /// for everyone added during onboarding. Returns the created members.
    func finalizeOnboarding(userID: UUID, draftMembers: [DraftFamilyMember]) async throws -> [FamilyMember] {
        let family: Family = try await client
            .from("families")
            .insert(FamilyInsert(name: "My family", created_by: userID))
            .select()
            .single()
            .execute()
            .value

        var inserts = [MemberInsert(
            family_id: family.id,
            profile_id: userID,
            relationship_label: "Me",
            is_remote: false,
            invite_email: nil,
            phone: nil
        )]
        inserts += draftMembers.map { draft in
            MemberInsert(
                family_id: family.id,
                profile_id: nil,
                relationship_label: draft.name,
                is_remote: draft.isRemote,
                invite_email: draft.email.isEmpty ? nil : draft.email,
                phone: draft.phone.isEmpty ? nil : draft.phone
            )
        }

        let members: [FamilyMember] = try await client
            .from("family_members")
            .insert(inserts)
            .select()
            .execute()
            .value
        return members
    }

    /// Joins an existing family using an invite code (definer RPC bypasses RLS).
    func acceptInvite(code: String) async throws {
        try await client
            .rpc("accept_family_invite", params: ["code": code])
            .execute()
    }

    /// Fetches the signed-in user's profile (created by the sign-up trigger).
    func fetchProfile(userID: UUID) async throws -> Profile {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
    }
}
