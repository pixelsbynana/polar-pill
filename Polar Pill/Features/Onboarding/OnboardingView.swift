//
//  OnboardingView.swift
//  Polar Pill
//
//  Welcome screen from the mockups: mascot, tagline, patient/caregiver
//  segmented control, "ADD YOUR FAMILY" list, and a pinned Continue button.
//

import SwiftUI

struct OnboardingView: View {
    private enum Step {
        case welcome   // mascot + Sign up / Log in
        case setup     // role picker + family setup (sign-up path only)
    }

    @Bindable var appState: AppState
    @State private var step: Step = .welcome
    @State private var showAddMemberSheet = false
    @State private var showInviteCodeSheet = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch step {
            case .welcome:
                welcome
            case .setup:
                setup
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step == .setup)
        .sheet(isPresented: $showAddMemberSheet) {
            AddFamilyMemberSheet { member in
                appState.draftMembers.append(member)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showInviteCodeSheet) {
            InviteCodeSheet(code: $appState.draftInviteCode)
                .presentationDetents([.height(260)])
        }
    }

    // MARK: - Step 1: Welcome (Sign up / Log in)

    private var welcome: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .accessibilityHidden(true)

            Text("Welcome to Polar Pill")
                .font(.title.bold())

            Text("Medication support built for families.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            Spacer()

            PrimaryButton(title: "Sign up") {
                step = .setup
            }

            SecondaryButton(title: "Log in") {
                appState.goToLogIn()
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: Role + family setup (sign-up only)

    private var setup: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            step = .welcome
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.title3)
                                .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                    .padding(.top, 8)

                    Image("Mascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .accessibilityHidden(true)

                    Text("Tell us about you")
                        .font(.title.bold())
                        .padding(.top, 12)

                    rolePicker
                        .padding(.top, 24)

                    // Caregivers set up their family here; patients typically
                    // join an existing one with an invite code instead.
                    if appState.draftRole == .caregiver {
                        familySection
                            .padding(.top, 32)
                    }

                    inviteCodeCard
                        .padding(.top, appState.draftRole == .caregiver ? 24 : 32)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }

            VStack {
                Spacer()
                PrimaryButton(title: "Continue") {
                    Task { await appState.continueFromOnboarding() }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(
                    Theme.background
                        .opacity(0.95)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
    }

    // MARK: - Role picker ("I'm a patient" / "I'm a caregiver")

    private var rolePicker: some View {
        HStack(spacing: 0) {
            roleButton(.patient, title: "I'm a patient")
            roleButton(.caregiver, title: "I'm a caregiver")
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    private func roleButton(_ role: UserRole, title: String) -> some View {
        Button {
            appState.draftRole = role
        } label: {
            Text(title)
                .font(.body.weight(appState.draftRole == role ? .bold : .regular))
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.minTapTarget + 4)
                .background(
                    appState.draftRole == role ? Theme.primaryTint : .clear,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(appState.draftRole == role ? Theme.primary : .clear, lineWidth: 1.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(appState.draftRole == role ? .isSelected : [])
    }

    // MARK: - Invite code card

    private var inviteCodeCard: some View {
        Button {
            showInviteCodeSheet = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "ticket")
                    .font(.title3)
                    .foregroundStyle(Theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.draftInviteCode.isEmpty
                         ? "Have an invite code?"
                         : "Joining with code \(appState.draftInviteCode)")
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                    Text(appState.draftInviteCode.isEmpty
                         ? "Join your family's existing account"
                         : "Tap to change the code")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(16)
            .background(
                appState.draftInviteCode.isEmpty ? Theme.card : Theme.primaryTint,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(appState.draftInviteCode.isEmpty ? Theme.cardBorder : Theme.primary,
                            lineWidth: appState.draftInviteCode.isEmpty ? 1 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.draftInviteCode.isEmpty
                            ? "Enter an invite code to join your family"
                            : "Joining with code \(appState.draftInviteCode), tap to change")
    }

    // MARK: - Family list

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD YOUR FAMILY")
                .font(.footnote.bold())
                .kerning(1)
                .foregroundStyle(Theme.primary)

            ForEach(appState.draftMembers) { member in
                FamilyMemberDraftRow(member: member)
            }

            Button {
                showAddMemberSheet = true
            } label: {
                Label("Add family member", systemImage: "plus")
                    .font(.body.bold())
                    .foregroundStyle(Theme.primary)
                    .frame(minHeight: Theme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Row for a member added during onboarding

private struct FamilyMemberDraftRow: View {
    let member: DraftFamilyMember

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Theme.primaryTint)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(Theme.primary)
                        .font(.title3)
                )

            Text(member.name)
                .font(.body.bold())

            Spacer()

            Image(systemName: "checkmark.circle")
                .foregroundStyle(Theme.primary)
                .font(.title3)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Invite code sheet

private struct InviteCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var code: String
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Invite code", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Enter the code a family member shared with you to join their family instead of creating a new one.")
                }
            }
            .navigationTitle("Join a family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        code = text
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { text = code }
        }
    }
}

#Preview {
    OnboardingView(appState: AppState())
}
