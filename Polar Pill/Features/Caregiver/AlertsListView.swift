//
//  AlertsListView.swift
//  Polar Pill
//
//  Notification center: full history of missed-medication alerts.
//  Unopened alerts are highlighted with a dot; opened ones are dimmed.
//  Tapping a row marks it opened and shows the "Check in on [Name]" detail.
//

import SwiftUI

struct AlertsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: DashboardViewModel
    @State private var openedAlert: MissedDoseAlert?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.alerts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.alerts) { alert in
                                alertRow(alert)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $openedAlert) { alert in
                MissedAlertView(
                    alert: alert,
                    member: viewModel.member(for: alert),
                    onAcknowledge: { await viewModel.acknowledge(alert) }
                )
            }
        }
    }

    private func alertRow(_ alert: MissedDoseAlert) -> some View {
        let isUnread = alert.acknowledgedAt == nil

        return Button {
            openedAlert = alert
            // Opening counts as reading it.
            Task { await viewModel.acknowledge(alert) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.body)
                    .foregroundStyle(isUnread ? Theme.danger : Theme.secondaryText)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.message)
                        .font(isUnread ? .subheadline.bold() : .subheadline)
                        .foregroundStyle(isUnread ? .primary : Theme.secondaryText)
                        .multilineTextAlignment(.leading)

                    Text(alert.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 8)

                if isUnread {
                    Circle()
                        .fill(Theme.primary)
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)
                        .accessibilityLabel("Unread")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isUnread ? Theme.primaryTint : Theme.card,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(isUnread ? Theme.primary.opacity(0.35) : Theme.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isUnread ? "Unread" : "Read") alert: \(alert.message)")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundStyle(Theme.secondaryText)
            Text("No notifications")
                .font(.headline)
            Text("Missed-medication alerts will appear here.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
    }
}
