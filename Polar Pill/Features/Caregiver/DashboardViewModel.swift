//
//  DashboardViewModel.swift
//  Polar Pill
//
//  Loads family members, today's medications and dose statuses for the
//  caregiver dashboard and patient detail screens.
//

import Foundation
import Supabase

@MainActor
@Observable
final class DashboardViewModel {
    var members: [FamilyMember] = []
    /// Medications keyed by family member id.
    var medicationsByMember: [UUID: [Medication]] = [:]
    /// Today's dose log per medication id.
    var todayLogByMedication: [UUID: DoseLog] = [:]
    /// Alert history (opened and unopened), newest first.
    var alerts: [MissedDoseAlert] = []
    /// The alert currently shown as the "Check in on [Name]" screen.
    var presentedAlert: MissedDoseAlert?
    var isLoading = false
    var errorMessage: String?

    /// Alerts not yet opened/acknowledged.
    var unreadAlertCount: Int { alerts.filter { $0.acknowledgedAt == nil }.count }

    private var realtimeTask: Task<Void, Never>?

    /// The signed-in user's profile id, used to hide their own "Me" row
    /// from the dashboard patient list.
    private let currentProfileID: UUID?

    private var service: DataService? {
        SupabaseService.shared.map { DataService(client: $0.client) }
    }

    init(currentProfileID: UUID?) {
        self.currentProfileID = currentProfileID
    }

    /// Family members shown as patient cards (everyone except the caregiver).
    var patients: [FamilyMember] {
        members.filter { $0.profileID == nil || $0.profileID != currentProfileID }
    }

    var familyID: UUID? { members.first?.familyID }

    /// Prevents overlapping loads (tab switches, realtime events, refresh)
    /// from racing each other.
    private var loadInProgress = false

    func load() async {
        guard let service else { return }
        guard !loadInProgress else { return }
        loadInProgress = true
        isLoading = members.isEmpty
        errorMessage = nil
        defer {
            loadInProgress = false
            isLoading = false
        }

        do {
            var members = try await service.fetchFamilyMembers()

            // No member row yet (interrupted onboarding)? Bootstrap it via an
            // idempotent server-side RPC — never creates duplicates.
            if members.isEmpty {
                let me = try await service.ensureSelfMembership()
                members = [me]
            }
            self.members = members

            let medications = try await service.fetchMedications(memberIDs: members.map(\.id))
            medicationsByMember = Dictionary(grouping: medications, by: \.familyMemberID)

            // Create today's pending logs (idempotent), then read statuses back.
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

            alerts = (try? await service.fetchAlerts()) ?? []
        } catch {
            // SwiftUI cancels .task/.refreshable work on view changes —
            // not a user-facing failure; the next load will succeed.
            guard !error.isTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Today's medications for a member, with display status and, for taken
    /// doses, the time they were confirmed.
    func todaysMedications(for member: FamilyMember) -> [(medication: Medication, status: DoseDisplayStatus, takenAt: Date?)] {
        (medicationsByMember[member.id] ?? [])
            .filter { $0.isScheduled(on: .now) }
            .map { medication in
                let log = todayLogByMedication[medication.id]
                return (medication,
                        DoseDisplayStatus(logStatus: log?.status),
                        log?.status == .taken ? log?.confirmedAt : nil)
            }
    }

    /// Week-to-date adherence for the detail header, using the same one-log
    /// per medication/day rule as the visible medication list.
    func weeklyDoseStats(for member: FamilyMember) async -> (taken: Int, scheduled: Int) {
        guard let service else { return (0, 0) }

        let medications = medicationsByMember[member.id] ?? []
        let medicationIDs = medications.map(\.id)
        guard !medicationIDs.isEmpty else { return (0, 0) }

        let calendar = Calendar.current
        let now = Date.now
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return (0, 0)
        }

        let logs = (try? await service.fetchDoseLogs(
            medicationIDs: medicationIDs,
            from: weekStart,
            to: tomorrowStart
        )) ?? []

        let currentLogs = latestDailyLogs(from: logs, calendar: calendar)
        return (currentLogs.filter { $0.status == .taken }.count, currentLogs.count)
    }

    func addMember(_ draft: DraftFamilyMember) async {
        guard let service else {
            errorMessage = "Supabase is not configured."
            return
        }
        do {
            // load() self-heals a missing family, so retry through it once.
            if familyID == nil {
                await load()
            }
            guard let familyID else {
                errorMessage = "Couldn't find or create your family. Pull to refresh and try again."
                return
            }
            let member = try await service.addFamilyMember(familyID: familyID, draft: draft)
            members.append(member)
        } catch {
            guard !error.isTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Alerts

    func member(for alert: MissedDoseAlert) -> FamilyMember? {
        members.first { $0.id == alert.familyMemberID }
    }

    /// Bell tap or notification deep link — presents the newest alert.
    func presentLatestAlert(id: UUID? = nil) {
        if let id, let match = alerts.first(where: { $0.id == id }) {
            presentedAlert = match
        } else {
            presentedAlert = alerts.first
        }
    }

    /// Marks an alert as opened/acknowledged. Idempotent — already-opened
    /// alerts stay in the history untouched.
    func acknowledge(_ alert: MissedDoseAlert) async {
        guard let service, alert.acknowledgedAt == nil else { return }
        do {
            let userID = try await service.currentUserID()
            try await service.acknowledgeAlert(id: alert.id, by: userID)
            if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
                alerts[index].acknowledgedAt = .now
                alerts[index].acknowledgedBy = userID
            }
        } catch {
            guard !error.isTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Realtime (live dashboard updates)

    /// Subscribes to alert inserts (notification + bell dot) and dose_log
    /// updates (live status flips when the patient confirms a dose).
    func startRealtime() {
        guard realtimeTask == nil, let client = SupabaseService.shared?.client else { return }
        realtimeTask = Task { [weak self] in
            let channel = client.channel("dashboard-live")
            let alertInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "alerts")
            let doseChanges = channel.postgresChange(UpdateAction.self, schema: "public", table: "dose_logs")
            await channel.subscribe()

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await insert in alertInserts {
                        guard let self else { return }
                        await self.handleAlertInsert(insert)
                    }
                }
                group.addTask {
                    for await _ in doseChanges {
                        guard let self else { return }
                        await self.load()
                    }
                }
            }
        }
    }

    private func handleAlertInsert(_ insert: InsertAction) async {
        guard let service else { return }
        alerts = (try? await service.fetchAlerts()) ?? alerts
        // Surface as a local notification (MVP stand-in for APNs push).
        if let newest = alerts.first(where: { $0.acknowledgedAt == nil }) {
            await NotificationManager.shared.postMissedDoseNotification(
                alertID: newest.id,
                message: newest.message
            )
        }
    }

    private func latestDailyLogs(from logs: [DoseLog], calendar: Calendar) -> [DoseLog] {
        Dictionary(
            logs.map { log in
                (DailyDoseKey(medicationID: log.medicationID, day: calendar.startOfDay(for: log.scheduledFor)), log)
            },
            uniquingKeysWith: { $0.scheduledFor > $1.scheduledFor ? $0 : $1 }
        )
        .values
        .map { $0 }
    }
}

private struct DailyDoseKey: Hashable {
    let medicationID: UUID
    let day: Date
}

extension Error {
    /// True for structured-concurrency/URLSession cancellations that should
    /// never be surfaced to the user.
    var isTaskCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
