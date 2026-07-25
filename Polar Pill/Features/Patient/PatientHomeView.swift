//
//  PatientHomeView.swift
//  Polar Pill
//
//  Patient home from the mockups: greeting, big Next Dose card with
//  "Waiting for tap…" + "Scan QR code", Today's Schedule, and a
//  "Call a family member" button. Minimal taps for elderly users.
//

import SwiftUI

struct PatientHomeView: View {
    let appState: AppState
    @State private var viewModel = PatientHomeViewModel()
    @State private var showScanner = false
    @State private var showCallSheet = false
    @State private var showSignOutConfirmation = false
    @State private var scanFeedback: String?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    greeting

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        nextDoseCard

                        Text("TODAY'S SCHEDULE")
                            .font(.footnote.bold())
                            .kerning(1)
                            .foregroundStyle(Theme.primary)

                        scheduleList

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Theme.danger)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }
            .refreshable { await viewModel.load() }

            VStack {
                Spacer()
                SecondaryButton(title: "Call a family member", systemImage: "phone") {
                    showCallSheet = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .task { await viewModel.load() }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerScreen { payload in
                Task {
                    let outcome = await viewModel.confirmDose(scannedPayload: payload, method: payload == nil ? .manual : .qr)
                    showScanner = false
                    // Let the scanner dismiss before presenting what's next.
                    try? await Task.sleep(for: .milliseconds(450))
                    switch outcome {
                    case .confirmed(let confirmation):
                        viewModel.lastConfirmed = confirmation
                    case .alreadyTaken(let medication):
                        scanFeedback = "\(medication.name) is already marked as taken today. All good!"
                    case .notScheduledToday(let medication):
                        scanFeedback = "\(medication.name) isn't scheduled for today."
                    case .unrecognizedCode:
                        scanFeedback = "That QR code doesn't match any of your medications. Try the label on the box, or mark the dose manually."
                    case .failed(let message):
                        scanFeedback = message
                    }
                }
            } onCancel: {
                showScanner = false
            }
        }
        .alert("Scan result", isPresented: Binding(
            get: { scanFeedback != nil },
            set: { if !$0 { scanFeedback = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scanFeedback ?? "")
        }
        .fullScreenCover(item: $viewModel.lastConfirmed) { confirmation in
            CelebrationView(confirmation: confirmation) {
                viewModel.lastConfirmed = nil
            }
        }
        .sheet(isPresented: $showCallSheet) {
            CallFamilySheet(members: viewModel.otherMembers, appState: appState)
                .presentationDetents([.medium])
        }
        .confirmationDialog("Sign out of Polar Pill?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(timeGreeting), \(firstName)")
                    .font(.title.bold())
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                if viewModel.streakDays > 1 {
                    Label("\(viewModel.streakDays)-day streak", systemImage: "flame")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.primaryTint, in: Capsule())
                        .padding(.top, 4)
                }
            }

            Spacer()

            Button {
                showSignOutConfirmation = true
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign out")
        }
    }

    private var firstName: String {
        (appState.profile?.fullName ?? "").components(separatedBy: " ").first ?? ""
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    // MARK: - Next dose card

    @ViewBuilder
    private var nextDoseCard: some View {
        if let next = viewModel.nextDose {
            VStack(spacing: 14) {
                Text("Next dose")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)

                Image(systemName: "pills")
                    .font(.largeTitle) // scales with Dynamic Type
                    .foregroundStyle(Theme.primary)
                    .accessibilityHidden(true)

                Text(next.medication.name)
                    .font(.title.bold())

                Text("\(next.medication.dosage)\(next.medication.dosage.isEmpty ? "" : " · ")\(next.medication.displayTime)")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)

                // QR is the primary confirmation path for the MVP
                // (NFC deliberately skipped; the waiting state below is
                // kept as a visual placeholder).
                PrimaryButton(title: "Scan QR code", systemImage: "qrcode.viewfinder") {
                    showScanner = true
                }
                .padding(.top, 6)

                Text("or")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)

                Label("Waiting for tap", systemImage: "dot.radiowaves.up.forward")
                    .font(.body.bold())
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(Theme.primaryTint, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(Theme.primary.opacity(0.25), lineWidth: 1)
            )
        } else {
            VStack(spacing: 12) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)
                Text(viewModel.todaysMedications.isEmpty ? "No medications today" : "All done for today!")
                    .font(.title3.bold())
                Text(viewModel.todaysMedications.isEmpty
                     ? "Doses your family sets up will appear here."
                     : "Every dose taken. Nice work!")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(Theme.primaryTint, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    // MARK: - Schedule

    @ViewBuilder
    private var scheduleList: some View {
        if viewModel.todaysMedications.isEmpty {
            Text("Nothing scheduled today.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        } else {
            ForEach(viewModel.todaysMedications, id: \.medication.id) { item in
                let status = DoseDisplayStatus(logStatus: item.log?.status)
                HStack(spacing: 12) {
                    Image(systemName: status == .taken ? "checkmark.circle" : "clock")
                        .foregroundStyle(status == .taken ? Theme.primary : Theme.secondaryText)
                    (Text(item.medication.name).bold()
                     + Text(" · \(item.medication.displayTime)").foregroundColor(Theme.secondaryText))
                        .font(.body)
                    Spacer()
                    StatusBadge(status: status)
                }
                .frame(minHeight: Theme.minTapTarget)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
            }
        }
    }
}
