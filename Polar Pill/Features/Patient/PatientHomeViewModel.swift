//
//  PatientHomeViewModel.swift
//  Polar Pill
//
//  Loads the patient's own medications and today's dose statuses, and
//  confirms doses (QR now, NFC in Milestone 6).
//

import Foundation
import Supabase

@MainActor
@Observable
final class PatientHomeViewModel {
    var selfMember: FamilyMember?
    /// Other members of the family (for "Call a family member").
    var otherMembers: [FamilyMember] = []
    var medications: [Medication] = []
    /// Today's dose log per medication id.
    var todayLogByMedication: [UUID: DoseLog] = [:]
    var isLoading = false
    var errorMessage: String?
    /// Consecutive days with 100% adherence, shown as a badge on the home screen.
    var streakDays = 0
    /// Set right after a successful confirmation — presents the celebration screen.
    var lastConfirmed: ConfirmedDose?

    private var service: DataService? {
        SupabaseService.shared.map { DataService(client: $0.client) }
    }

    /// Medications scheduled today, ordered by dose time.
    var todaysMedications: [(medication: Medication, log: DoseLog?)] {
        medications
            .filter { $0.isScheduled(on: .now) }
            .sorted { $0.scheduledDate(on: .now) < $1.scheduledDate(on: .now) }
            .map { ($0, todayLogByMedication[$0.id]) }
    }

    /// The earliest dose today that hasn't been taken yet.
    var nextDose: (medication: Medication, log: DoseLog)? {
        for item in todaysMedications {
            if let log = item.log, log.status == .pending {
                return (item.medication, log)
            }
        }
        return nil
    }

    /// Prevents overlapping loads from racing each other.
    private var loadInProgress = false

    func load() async {
        guard let service else { return }
        guard !loadInProgress else { return }
        loadInProgress = true
        isLoading = medications.isEmpty && selfMember == nil
        errorMessage = nil
        defer {
            loadInProgress = false
            isLoading = false
        }

        do {
            let userID = try await service.currentUserID()
            var members = try await service.fetchFamilyMembers()

            // No member row yet (interrupted onboarding)? Bootstrap it via an
            // idempotent server-side RPC — never creates duplicates.
            if members.isEmpty {
                members = [try await service.ensureSelfMembership()]
            }

            selfMember = members.first { $0.profileID == userID }
            otherMembers = members.filter { $0.profileID != userID }

            guard let selfMember else { return }
            let medications = try await service.fetchMedications(memberIDs: [selfMember.id])
            self.medications = medications

            try await service.ensureDoseLogs(for: medications)
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: .now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? .now
            let logs = try await service.fetchDoseLogs(
                medicationIDs: medications.map(\.id),
                from: startOfDay,
                to: endOfDay
            )
            // A medication can have two logs today if its time was edited
            // after the first was created — keep the latest-scheduled one.
            todayLogByMedication = Dictionary(
                logs.map { ($0.medicationID, $0) },
                uniquingKeysWith: { $0.scheduledFor > $1.scheduledFor ? $0 : $1 }
            )

            // Keep local dose reminders in sync with the medication list.
            await NotificationManager.shared.scheduleDoseReminders(for: medications)

            streakDays = await computeStreakDays()
        } catch {
            guard !error.isTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Outcome of a QR scan or manual confirmation.
    enum ScanOutcome {
        case confirmed(ConfirmedDose)
        case alreadyTaken(Medication)
        case notScheduledToday(Medication)
        case unrecognizedCode
        case failed(String)
    }

    /// Confirms a dose after a QR scan (payload) or manual confirmation (nil).
    /// A scanned QR only ever confirms the exact medication it encodes —
    /// never falls back to a different one.
    func confirmDose(scannedPayload: String?, method: ConfirmationMethod) async -> ScanOutcome {
        // Manual confirmation (no QR): the next pending dose.
        guard let payload = scannedPayload?.lowercased() else {
            guard let next = nextDose else {
                return .failed("Everything scheduled so far today is already taken.")
            }
            return await confirm(medication: next.medication, log: next.log, method: method)
        }

        // Strict match on the medication UUID embedded in the label.
        guard let medication = medications.first(where: { payload.contains($0.id.uuidString.lowercased()) }) else {
            return .unrecognizedCode
        }
        guard let log = todayLogByMedication[medication.id] else {
            return .notScheduledToday(medication)
        }
        if log.status == .taken {
            return .alreadyTaken(medication)
        }
        // pending — or missed, which we still allow (taking it late is
        // better than not at all, and the caregiver sees the confirmation).
        return await confirm(medication: medication, log: log, method: method)
    }

    private func confirm(medication: Medication, log: DoseLog, method: ConfirmationMethod) async -> ScanOutcome {
        guard let service else { return .failed("Supabase is not configured.") }
        do {
            let updated = try await service.confirmDose(logID: log.id, method: method)
            todayLogByMedication[updated.medicationID] = updated
            let streak = await computeStreakDays()
            streakDays = streak
            return .confirmed(ConfirmedDose(medication: medication, log: updated, streakDays: streak))
        } catch {
            guard !error.isTaskCancellation else { return .failed("Cancelled — please try again.") }
            return .failed(error.localizedDescription)
        }
    }

    /// Consecutive days (ending today) with 100% adherence.
    /// A past day counts when it has doses and all were taken; today ignores
    /// doses that aren't due yet. Looks back up to 60 days.
    private func computeStreakDays() async -> Int {
        guard let service, !medications.isEmpty else { return 0 }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        guard let windowStart = calendar.date(byAdding: .day, value: -60, to: todayStart),
              let windowEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return 0 }

        let logs = (try? await service.fetchDoseLogs(
            medicationIDs: medications.map(\.id),
            from: windowStart,
            to: windowEnd
        )) ?? []
        let logsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.scheduledFor) }

        var streak = 0
        var day = todayStart
        while let dayLogs = logsByDay[day] {
            let relevant = calendar.isDateInToday(day)
                ? dayLogs.filter { $0.scheduledFor <= .now || $0.status == .taken }
                : dayLogs
            guard !relevant.isEmpty, relevant.allSatisfy({ $0.status == .taken }) else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}

/// A freshly confirmed dose, shown on the celebration screen.
struct ConfirmedDose: Identifiable {
    let id = UUID()
    let medication: Medication
    let log: DoseLog
    let streakDays: Int
}
