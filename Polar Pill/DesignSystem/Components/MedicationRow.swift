//
//  MedicationRow.swift
//  Polar Pill
//
//  Medication list rows from the mockups.
//  .compact — dashboard cards:  ⌁ Metformin · 8:00 AM        [Taken]
//  .detail  — patient detail:   ⌁ Metformin 500mg / 8:00 AM  [Taken]
//

import SwiftUI

struct MedicationRow: View {
    enum Layout {
        case compact
        case detail
    }

    let name: String
    var dosage: String = ""
    let time: String
    let status: DoseDisplayStatus
    /// When the dose was actually confirmed (shown for taken doses).
    var takenAt: Date? = nil
    var layout: Layout = .detail

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pills")
                .foregroundStyle(Theme.secondaryText)
                .font(layout == .detail ? .body : .subheadline)

            VStack(alignment: .leading, spacing: 3) {
                if layout == .compact {
                    (Text(name).bold() + Text(" · \(time)").foregroundColor(Theme.secondaryText))
                        .font(.subheadline)
                        .lineLimit(1)
                } else {
                    (Text(name).bold() + Text(dosage.isEmpty ? "" : " \(dosage)").foregroundColor(Theme.secondaryText))
                        .font(.body)
                    Text(time)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }

                if let takenAt {
                    Text("Taken at \(takenAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Theme.primary)
                }
            }

            Spacer(minLength: 8)

            StatusBadge(status: status)
        }
        .frame(minHeight: Theme.minTapTarget)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        MedicationRow(name: "Metformin", time: "8:00 AM", status: .taken, takenAt: .now, layout: .compact)
        MedicationRow(name: "Ramipril", time: "12:00 PM", status: .missed, layout: .compact)
        MedicationRow(name: "Metformin", dosage: "500mg", time: "8:00 AM", status: .taken, takenAt: .now)
        MedicationRow(name: "Atorvastatin", dosage: "20mg", time: "9:00 PM", status: .later)
    }
    .padding()
    .background(Theme.background)
}
