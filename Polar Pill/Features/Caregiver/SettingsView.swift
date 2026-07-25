//
//  SettingsView.swift
//  Polar Pill
//
//  Minimal MVP settings: profile info, family invite codes, sign out.
//

import SwiftUI

struct SettingsView: View {
    let appState: AppState
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    LabeledContent("Name", value: appState.profile?.fullName ?? "—")
                    LabeledContent("Role", value: appState.profile?.role.rawValue.capitalized ?? "—")
                }

                Section {
                    ForEach(viewModel.members) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.displayName)
                                .font(.body.bold())
                            if member.acceptedAt == nil, member.profileID == nil {
                                // Pending invite — share the code so they can join.
                                ShareLink(item: "Join our family on Polar Pill! Use invite code: \(member.inviteCode)") {
                                    Label("Share invite code \(member.inviteCode)", systemImage: "square.and.arrow.up")
                                        .font(.subheadline)
                                }
                            } else {
                                Text("Joined")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Family")
                } footer: {
                    Text("Family members install Polar Pill and enter their invite code during onboarding to link accounts.")
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await appState.signOut() }
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
        .task { if viewModel.members.isEmpty { await viewModel.load() } }
    }
}
