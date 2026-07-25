//
//  DataService.swift
//  Polar Pill
//
//  CRUD for family members, medications, and dose logs. RLS scopes every
//  query to the signed-in user's family, so no explicit family filtering
//  is needed client-side.
//

import Foundation
import Supabase

struct DataService {
    let client: SupabaseClient

    private static let isoFormatter = ISO8601DateFormatter()

    /// The authenticated user's id from the live session (refreshing the
    /// token if needed). Throws if signed out — callers should route to auth.
    func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }

    // MARK: - Families

    /// Idempotent bootstrap: returns the current user's member row, creating
    /// their family + "Me" row server-side only if they truly have none.
    /// Safe to call repeatedly/concurrently — never creates duplicates.
    func ensureSelfMembership() async throws -> FamilyMember {
        try await client
            .rpc("ensure_self_membership")
            .execute()
            .value
    }

    // MARK: - Family members

    /// All members visible to the current user (their own families).
    func fetchFamilyMembers() async throws -> [FamilyMember] {
        try await client
            .from("family_members")
            .select()
            .order("created_at")
            .execute()
            .value
    }

    private struct MemberInsert: Encodable {
        let family_id: UUID
        let relationship_label: String
        let invite_email: String?
        let phone: String?
    }

    func addFamilyMember(familyID: UUID, draft: DraftFamilyMember) async throws -> FamilyMember {
        try await client
            .from("family_members")
            .insert(MemberInsert(
                family_id: familyID,
                relationship_label: draft.name,
                invite_email: draft.email.isEmpty ? nil : draft.email,
                phone: draft.phone.isEmpty ? nil : draft.phone
            ))
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Medications

    func fetchMedications(memberIDs: [UUID]) async throws -> [Medication] {
        guard !memberIDs.isEmpty else { return [] }
        return try await client
            .from("medications")
            .select()
            .in("family_member_id", values: memberIDs.map(\.uuidString))
            .order("time_of_day")
            .execute()
            .value
    }

    struct MedicationPayload: Encodable {
        let family_member_id: UUID
        let name: String
        let dosage: String
        let time_of_day: String
        let frequency: String
        let custom_schedule: CustomSchedule?
        let reminders_enabled: Bool
        let created_by: UUID?
    }

    func createMedication(_ payload: MedicationPayload) async throws -> Medication {
        try await client
            .from("medications")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateMedication(id: UUID, _ payload: MedicationPayload) async throws -> Medication {
        try await client
            .from("medications")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteMedication(id: UUID) async throws {
        try await client
            .from("medications")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Dose logs

    private struct DoseLogInsert: Encodable {
        let medication_id: UUID
        let scheduled_for: Date
    }

    /// Creates today's pending dose_log rows for any medication scheduled
    /// today that doesn't have one yet (idempotent thanks to the unique
    /// (medication_id, scheduled_for) constraint + ignoreDuplicates).
    func ensureDoseLogs(for medications: [Medication], on day: Date = .now) async throws {
        let inserts = medications
            .filter { $0.isScheduled(on: day) }
            .map { DoseLogInsert(medication_id: $0.id, scheduled_for: $0.scheduledDate(on: day)) }
        guard !inserts.isEmpty else { return }

        try await client
            .from("dose_logs")
            .upsert(inserts, onConflict: "medication_id,scheduled_for", ignoreDuplicates: true)
            .execute()
    }

    /// Removes today's still-pending logs for a medication — used when its
    /// schedule is edited, so a stale log at the old time doesn't linger
    /// (and later get falsely marked as missed). Taken/missed logs stay.
    func deletePendingDoseLogs(medicationID: UUID, on day: Date = .now) async throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? day
        try await client
            .from("dose_logs")
            .delete()
            .eq("medication_id", value: medicationID.uuidString)
            .eq("status", value: DoseStatus.pending.rawValue)
            .gte("scheduled_for", value: Self.isoFormatter.string(from: startOfDay))
            .lt("scheduled_for", value: Self.isoFormatter.string(from: endOfDay))
            .execute()
    }

    func fetchDoseLogs(medicationIDs: [UUID], from start: Date, to end: Date) async throws -> [DoseLog] {
        guard !medicationIDs.isEmpty else { return [] }
        return try await client
            .from("dose_logs")
            .select()
            .in("medication_id", values: medicationIDs.map(\.uuidString))
            .gte("scheduled_for", value: Self.isoFormatter.string(from: start))
            .lt("scheduled_for", value: Self.isoFormatter.string(from: end))
            .order("scheduled_for")
            .execute()
            .value
    }

    /// Marks a dose as taken (used by QR/NFC/manual confirmation flows).
    func confirmDose(logID: UUID, method: ConfirmationMethod) async throws -> DoseLog {
        struct Confirmation: Encodable {
            let status: String
            let confirmed_at: Date
            let confirmation_method: String
        }
        return try await client
            .from("dose_logs")
            .update(Confirmation(status: DoseStatus.taken.rawValue,
                                 confirmed_at: .now,
                                 confirmation_method: method.rawValue))
            .eq("id", value: logID.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Alerts

    /// Unacknowledged alerts, newest first (drives the bell badge + alert screen).
    func fetchUnacknowledgedAlerts() async throws -> [MissedDoseAlert] {
        try await client
            .from("alerts")
            .select()
            .is("acknowledged_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// "I'll check now" — records who acknowledged, leaves the dose status untouched.
    func acknowledgeAlert(id: UUID, by profileID: UUID?) async throws {
        struct Acknowledgement: Encodable {
            let acknowledged_by: UUID?
            let acknowledged_at: Date
        }
        try await client
            .from("alerts")
            .update(Acknowledgement(acknowledged_by: profileID, acknowledged_at: .now))
            .eq("id", value: id.uuidString)
            .execute()
    }
}
