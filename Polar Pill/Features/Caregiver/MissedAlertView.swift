//
//  MissedAlertView.swift
//  Polar Pill
//
//  Missed medication alert from the mockups: notification mini-card,
//  warning icon, "Check in on [Name]", Call + "I'll check now" buttons.
//

import SwiftUI

struct MissedAlertView: View {
    @Environment(\.dismiss) private var dismiss

    let alert: MissedDoseAlert
    let member: FamilyMember?
    /// Marks the alert acknowledged (does not change the dose status).
    let onAcknowledge: () async -> Void

    @State private var showNoPhoneAlert = false

    private var name: String { member?.displayName ?? "your family member" }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                notificationCard
                    .padding(.top, 16)

                Spacer()

                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.card)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(Theme.navy)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                Text("Check in on \(name)")
                    .font(.title2.bold())

                Text("\(alert.message) Probably nothing, but worth a quick call.")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                PrimaryButton(title: "Call \(name)", systemImage: "phone.fill") {
                    call()
                }
                .padding(.horizontal, 24)

                SecondaryButton(title: "I'll check now") {
                    Task {
                        await onAcknowledge()
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(20)
        }
        .alert("No phone number", isPresented: $showNoPhoneAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add a phone number for \(name) to call them from here.")
        }
    }

    /// Mimics the push notification that delivered this alert.
    private var notificationCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Polar Pill")
                    .font(.footnote.bold())
                Text(alert.message)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    private func call() {
        guard let phone = member?.phone,
              let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })"),
              UIApplication.shared.canOpenURL(url) else {
            showNoPhoneAlert = true
            return
        }
        UIApplication.shared.open(url)
    }
}
