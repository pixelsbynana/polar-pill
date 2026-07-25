//
//  FamilyMemberCard.swift
//  Polar Pill
//
//  Dashboard card: avatar + name header, then today's medications with
//  status badges, as in the caregiver mockup.
//

import SwiftUI

struct FamilyMemberCard: View {
    let name: String
    /// (name, time, status, takenAt) per medication scheduled today.
    let medications: [(name: String, time: String, status: DoseDisplayStatus, takenAt: Date?)]
    /// When set, shows a "Print QR labels" button next to the name.
    var onPrintLabels: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.primaryTint)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Theme.primary)
                    )
                Text(name)
                    .font(.body.bold())
                Spacer()
                if let onPrintLabels {
                    Button(action: onPrintLabels) {
                        Label("Print QR labels", systemImage: "printer")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Theme.primaryTint, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Print QR labels for \(name)'s medications")
                }
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            if medications.isEmpty {
                Text("No medications today")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(16)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(medications.enumerated()), id: \.offset) { _, med in
                        MedicationRow(name: med.name, time: med.time, status: med.status, takenAt: med.takenAt, layout: .compact)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        FamilyMemberCard(name: "Mum", medications: [
            ("Metformin", "8:00 AM", .taken, .now),
            ("Ramipril", "12:00 PM", .missed, nil),
        ], onPrintLabels: {})
        FamilyMemberCard(name: "Dad", medications: [
            ("Warfarin", "7:00 AM", .taken, .now),
        ])
    }
    .padding()
    .background(Theme.background)
}
