//
//  Models.swift
//  Polar Pill
//
//  Codable domain models mirroring the Supabase schema.
//  Explicit snake_case CodingKeys so no decoder configuration is required.
//

import Foundation

enum UserRole: String, Codable, CaseIterable, Sendable {
    case patient
    case caregiver
}

struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var fullName: String
    var role: UserRole
    var avatarURL: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case role
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }
}

struct Family: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct FamilyMember: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let familyID: UUID
    var profileID: UUID?
    var relationshipLabel: String?
    var isRemote: Bool
    var inviteEmail: String?
    let inviteCode: String
    var phone: String?
    var acceptedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case familyID = "family_id"
        case profileID = "profile_id"
        case relationshipLabel = "relationship_label"
        case isRemote = "is_remote"
        case inviteEmail = "invite_email"
        case inviteCode = "invite_code"
        case phone
        case acceptedAt = "accepted_at"
        case createdAt = "created_at"
    }

    /// Display name shown in lists (e.g. "Mum", "Dad").
    var displayName: String {
        relationshipLabel ?? "Family member"
    }
}

// MARK: - Medications

enum MedFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case custom

    var displayName: String { rawValue.capitalized }
}

/// jsonb payload for weekly/custom schedules. Weekdays are 1 = Monday … 7 = Sunday.
struct CustomSchedule: Codable, Hashable, Sendable {
    var weekdays: [Int]
}

struct Medication: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let familyMemberID: UUID
    var name: String
    var dosage: String
    /// Postgres `time` column, e.g. "08:00:00".
    var timeOfDay: String
    var frequency: MedFrequency
    var customSchedule: CustomSchedule?
    var remindersEnabled: Bool
    let createdBy: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case familyMemberID = "family_member_id"
        case name
        case dosage
        case timeOfDay = "time_of_day"
        case frequency
        case customSchedule = "custom_schedule"
        case remindersEnabled = "reminders_enabled"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    /// Hour/minute parsed from time_of_day.
    var timeComponents: (hour: Int, minute: Int) {
        let parts = timeOfDay.split(separator: ":").compactMap { Int($0) }
        return (parts.count > 0 ? parts[0] : 8, parts.count > 1 ? parts[1] : 0)
    }

    /// The dose time on a given day, in the current calendar.
    func scheduledDate(on day: Date, calendar: Calendar = .current) -> Date {
        let time = timeComponents
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) ?? day
    }

    /// "8:00 AM"-style display time.
    var displayTime: String {
        scheduledDate(on: .now).formatted(date: .omitted, time: .shortened)
    }

    /// Whether a dose is due on the given day.
    /// Assumption: weekly/custom use custom_schedule weekdays; a weekly med
    /// without a schedule falls back to the weekday it was created.
    func isScheduled(on day: Date, calendar: Calendar = .current) -> Bool {
        switch frequency {
        case .daily:
            return true
        case .weekly, .custom:
            let weekday = mondayBasedWeekday(of: day, calendar: calendar)
            if let weekdays = customSchedule?.weekdays, !weekdays.isEmpty {
                return weekdays.contains(weekday)
            }
            return weekday == mondayBasedWeekday(of: createdAt, calendar: calendar)
        }
    }

    private func mondayBasedWeekday(of date: Date, calendar: Calendar) -> Int {
        // Calendar.weekday is 1 = Sunday; convert to 1 = Monday … 7 = Sunday.
        let sundayBased = calendar.component(.weekday, from: date)
        return sundayBased == 1 ? 7 : sundayBased - 1
    }
}

// MARK: - Dose logs

enum DoseStatus: String, Codable, Sendable {
    case pending
    case taken
    case missed
}

enum ConfirmationMethod: String, Codable, Sendable {
    case nfc
    case qr
    case manual
}

// MARK: - Report periods

enum SummaryPeriod: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
    case yearly

    var displayName: String { rawValue.capitalized }
}

// MARK: - Alerts

/// A missed-dose alert raised by the server-side sweep.
/// (Named to avoid clashing with SwiftUI.Alert.)
struct MissedDoseAlert: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let familyMemberID: UUID
    let doseLogID: UUID?
    let message: String
    var acknowledgedBy: UUID?
    var acknowledgedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case familyMemberID = "family_member_id"
        case doseLogID = "dose_log_id"
        case message
        case acknowledgedBy = "acknowledged_by"
        case acknowledgedAt = "acknowledged_at"
        case createdAt = "created_at"
    }
}

struct DoseLog: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let medicationID: UUID
    let scheduledFor: Date
    var status: DoseStatus
    var confirmedAt: Date?
    var confirmationMethod: ConfirmationMethod?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case medicationID = "medication_id"
        case scheduledFor = "scheduled_for"
        case status
        case confirmedAt = "confirmed_at"
        case confirmationMethod = "confirmation_method"
        case createdAt = "created_at"
    }
}
