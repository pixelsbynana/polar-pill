//
//  ReportsViewModel.swift
//  Polar Pill
//
//  Weekly/Monthly/Yearly adherence report: stats + chart from dose_logs,
//  and a warm, plain-language summary generated locally on-device
//  (AI/Claude integration deliberately removed from the MVP).
//

import Foundation
import Supabase

@MainActor
@Observable
final class ReportsViewModel {
    var period: SummaryPeriod = .weekly
    var selectedMember: FamilyMember?
    var dosesTaken = 0
    var dosesScheduled = 0
    var chartDays: [AdherenceDay] = []
    var summaryText: String?
    var isLoading = false
    var errorMessage: String?

    private var client: SupabaseClient? { SupabaseService.shared?.client }

    var adherencePercent: Int {
        dosesScheduled == 0 ? 0 : Int((Double(dosesTaken) / Double(dosesScheduled) * 100).rounded())
    }

    /// "16–22 July"-style label for the current period.
    var periodLabel: String {
        let (start, end) = periodBounds()
        switch period {
        case .weekly:
            let endDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
            return "\(start.formatted(.dateTime.day()))–\(endDay.formatted(.dateTime.day().month(.wide)))"
        case .monthly:
            return start.formatted(.dateTime.month(.wide).year())
        case .yearly:
            return start.formatted(.dateTime.year())
        }
    }

    func load(member: FamilyMember) async {
        guard let client else { return }
        selectedMember = member
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let service = DataService(client: client)
            let medications = try await service.fetchMedications(memberIDs: [member.id])
            let (start, end) = periodBounds()
            let logs = try await service.fetchDoseLogs(
                medicationIDs: medications.map(\.id),
                from: start,
                to: end
            )

            dosesTaken = logs.filter { $0.status == .taken }.count
            dosesScheduled = logs.count
            chartDays = bucketize(logs: logs, from: start, to: end)
            summaryText = makeSummary(member: member, medications: medications, logs: logs)
        } catch {
            guard !error.isTaskCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Local summary generation

    /// Builds a short, warm, non-alarming summary from the raw dose data —
    /// same voice as the mockups, no external AI service required.
    private func makeSummary(member: FamilyMember, medications: [Medication], logs: [DoseLog]) -> String? {
        guard !logs.isEmpty else { return nil }

        let name = member.displayName
        let periodNoun = switch period {
        case .weekly: "week"
        case .monthly: "month"
        case .yearly: "year"
        }

        // Opening line scaled to adherence.
        var sentences: [String] = []
        switch adherencePercent {
        case 100:
            sentences.append("A perfect \(periodNoun) for \(name) — every one of the \(dosesScheduled) scheduled doses was taken.")
        case 85...:
            sentences.append("A strong \(periodNoun) for \(name) — \(dosesTaken) of \(dosesScheduled) doses taken.")
        case 60..<85:
            sentences.append("A mixed \(periodNoun) for \(name) — \(dosesTaken) of \(dosesScheduled) doses taken.")
        default:
            sentences.append("A tougher \(periodNoun) for \(name) — \(dosesTaken) of \(dosesScheduled) doses taken.")
        }

        // Missed doses, grouped per medication with weekday names.
        let medNames = Dictionary(uniqueKeysWithValues: medications.map { ($0.id, $0.name) })
        let missed = logs.filter { $0.status == .missed }
        if !missed.isEmpty {
            let byMedication = Dictionary(grouping: missed) { $0.medicationID }
            let details = byMedication.compactMap { medicationID, misses -> String? in
                guard let medName = medNames[medicationID] else { return nil }
                let days = misses
                    .sorted { $0.scheduledFor < $1.scheduledFor }
                    .prefix(4)
                    .map { $0.scheduledFor.formatted(.dateTime.weekday(.wide)) }
                let dayList = days.count == 1
                    ? days[0]
                    : days.dropLast().joined(separator: ", ") + " and " + days.last!
                return "\(medName) on \(dayList)"
            }
            if !details.isEmpty {
                sentences.append("Missed: \(details.joined(separator: "; ")).")
            }
        }

        // Gentle closing note.
        switch adherencePercent {
        case 100:
            sentences.append("Nothing to follow up on — a lovely result.")
        case 85...:
            sentences.append("Nothing urgent, just worth a gentle mention next time you speak.")
        case 60..<85:
            sentences.append("It might be worth a friendly check-in to see if the routine needs adjusting.")
        default:
            sentences.append("A caring conversation about what's getting in the way could really help.")
        }

        return sentences.joined(separator: " ")
    }

    // MARK: - Period math

    /// [start, end) of the selected period containing today.
    private func periodBounds() -> (Date, Date) {
        let calendar = Calendar.current
        let component: Calendar.Component = switch period {
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
        let interval = calendar.dateInterval(of: component, for: .now)
            ?? DateInterval(start: .now, duration: 0)
        return (interval.start, interval.end)
    }

    /// Buckets logs into chart bars: days (weekly), weeks (monthly), months (yearly).
    private func bucketize(logs: [DoseLog], from start: Date, to end: Date) -> [AdherenceDay] {
        let calendar = Calendar.current

        let (bucketComponent, labelFormat): (Calendar.Component, Date.FormatStyle) = switch period {
        case .weekly: (.day, .dateTime.weekday(.narrow))
        case .monthly: (.weekOfYear, .dateTime.day())
        case .yearly: (.month, .dateTime.month(.narrow))
        }

        var days: [AdherenceDay] = []
        var cursor = start
        while cursor < end && cursor <= .now {
            guard let bucketEnd = calendar.date(byAdding: bucketComponent, value: 1, to: cursor) else { break }
            let bucketLogs = logs.filter { $0.scheduledFor >= cursor && $0.scheduledFor < bucketEnd }
            let taken = bucketLogs.filter { $0.status == .taken }.count
            days.append(AdherenceDay(
                label: cursor.formatted(labelFormat),
                ratio: bucketLogs.isEmpty ? nil : Double(taken) / Double(bucketLogs.count),
                allTaken: !bucketLogs.isEmpty && taken == bucketLogs.count
            ))
            cursor = bucketEnd
        }
        return days
    }
}
