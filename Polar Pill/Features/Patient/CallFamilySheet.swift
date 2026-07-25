//
//  CallFamilySheet.swift
//  Polar Pill
//
//  "Call a family member" — big, simple rows that deep-link to the Phone app.
//

import SwiftUI

struct CallFamilySheet: View {
    @Environment(\.dismiss) private var dismiss
    let members: [FamilyMember]
    let appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if members.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.secondaryText)
                        Text("No family members yet")
                            .font(.headline)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(members) { member in
                                Button {
                                    call(member)
                                } label: {
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(Theme.primaryTint)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundStyle(Theme.primary)
                                            )
                                        Text(member.displayName)
                                            .font(.body.bold())
                                        Spacer()
                                        Image(systemName: "phone.fill")
                                            .foregroundStyle(member.phone == nil ? Theme.secondaryText : Theme.primary)
                                    }
                                    .padding(16)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                            .stroke(Theme.cardBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(member.phone == nil)
                                .opacity(member.phone == nil ? 0.5 : 1)
                            }

                            Text("Family members without a phone number appear dimmed.")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Call a family member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func call(_ member: FamilyMember) {
        guard let phone = member.phone,
              let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
