//
//  CelebrationView.swift
//  Polar Pill
//
//  Dark navy confirmation moment from the mockups: "Tap detected" chip,
//  mascot tile, "Nice work!", dose summary, streak badge, Done button.
//

import SwiftUI

struct CelebrationView: View {
    let confirmation: ConfirmedDose
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Theme.navy.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text("QR code scanned")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.14), in: Capsule())

                RoundedRectangle(cornerRadius: 22)
                    .fill(.white)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Image("Mascot")
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    )
                    .accessibilityHidden(true)

                Text("Nice work!")
                    .font(.largeTitle.bold()) // scales with Dynamic Type
                    .foregroundStyle(.white)

                Text("\(confirmation.medication.name) marked as taken at \(confirmedTime).")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if confirmation.streakDays > 1 {
                    Text("\(confirmation.streakDays)-day streak")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                }

                Button(action: onDone) {
                    Text("Done")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .frame(minHeight: Theme.minTapTarget + 4)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.6), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                Spacer()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var confirmedTime: String {
        (confirmation.log.confirmedAt ?? .now).formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    CelebrationView(
        confirmation: ConfirmedDose(
            medication: Medication(
                id: UUID(),
                familyMemberID: UUID(),
                name: "Metformin",
                dosage: "500mg",
                timeOfDay: "08:00:00",
                frequency: .daily,
                customSchedule: nil,
                remindersEnabled: true,
                createdBy: nil,
                createdAt: .now
            ),
            log: DoseLog(
                id: UUID(),
                medicationID: UUID(),
                scheduledFor: .now,
                status: .taken,
                confirmedAt: .now,
                confirmationMethod: .qr,
                createdAt: .now
            ),
            streakDays: 5
        ),
        onDone: {}
    )
}
