//
//  DashboardView.swift
//  Polar Pill
//
//  Family medication dashboard: logo header + notification bell,
//  "Today · [Day]", a FamilyMemberCard per patient, "+ Add family member".
//

import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @State private var showAddMemberSheet = false
    @State private var showAlertsList = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)

                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else if viewModel.patients.isEmpty {
                            emptyState
                        } else {
                            ForEach(viewModel.patients) { member in
                                NavigationLink(value: member) {
                                    FamilyMemberCard(
                                        name: member.displayName,
                                        medications: viewModel.todaysMedications(for: member).map {
                                            ($0.medication.name, $0.medication.displayTime, $0.status, $0.takenAt)
                                        },
                                        // Only offered when the member has medications.
                                        onPrintLabels: (viewModel.medicationsByMember[member.id] ?? []).isEmpty
                                            ? nil
                                            : { printLabels(for: member) }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            showAddMemberSheet = true
                        } label: {
                            Label("Add family member", systemImage: "plus")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.primary)
                                .frame(minHeight: Theme.minTapTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Theme.danger)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await viewModel.load() }
            }
            .navigationDestination(for: FamilyMember.self) { member in
                PatientDetailView(member: member, dashboard: viewModel)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.load()
            viewModel.startRealtime()
            // Tapping a missed-dose notification deep-links to the alert screen.
            NotificationManager.shared.onMissedDoseAlertTapped = { alertID in
                viewModel.presentLatestAlert(id: alertID)
            }
        }
        .sheet(isPresented: $showAddMemberSheet) {
            AddFamilyMemberSheet { draft in
                Task { await viewModel.addMember(draft) }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAlertsList) {
            AlertsListView(viewModel: viewModel)
        }
        // Push-notification deep links still open the alert detail directly.
        .sheet(item: $viewModel.presentedAlert) { alert in
            MissedAlertView(
                alert: alert,
                member: viewModel.member(for: alert),
                onAcknowledge: { await viewModel.acknowledge(alert) }
            )
        }
    }

    /// One page with a QR label for every medication this member takes,
    /// straight to the AirPrint dialog.
    private func printLabels(for member: FamilyMember) {
        let medications = viewModel.medicationsByMember[member.id] ?? []
        guard let url = MedicationLabelsPDF.render(medications: medications, patientName: member.displayName) else { return }
        LabelPrinter.printPDF(at: url, jobName: "Polar Pill — \(member.displayName) QR labels")
    }

    // MARK: - Header (logo + bell)

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text("Polar Pill")
                    .font(.headline.bold())
            }

            Spacer()

            // Bell with unread-alert badge dot; tap opens the notification list.
            Button {
                showAlertsList = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title3)
                        .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
                        .contentShape(Circle())
                    if viewModel.unreadAlertCount > 0 {
                        Circle()
                            .fill(Theme.danger)
                            .frame(width: 10, height: 10)
                            .offset(x: -6, y: 6)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.unreadAlertCount > 0
                                ? "Notifications: \(viewModel.unreadAlertCount) unread"
                                : "Notifications")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)
            Text("No family members yet")
                .font(.headline)
            Text("Add a family member to start tracking their medication.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
