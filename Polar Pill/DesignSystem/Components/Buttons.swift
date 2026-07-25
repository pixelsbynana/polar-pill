//
//  Buttons.swift
//  Polar Pill
//
//  PrimaryButton / SecondaryButton matching the mockups: rounded, full-width,
//  bold labels, generous 44pt+ tap targets for elderly users.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.minTapTarget + 8)
            .contentShape(RoundedRectangle(cornerRadius: 14)) // whole button tappable
        }
        .buttonStyle(.plain)
        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.white)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.minTapTarget + 8)
            .contentShape(RoundedRectangle(cornerRadius: 14)) // whole button tappable
        }
        .buttonStyle(.plain)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .foregroundStyle(.primary)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue") {}
        SecondaryButton(title: "Cancel") {}
        PrimaryButton(title: "Call Mum", systemImage: "phone.fill") {}
    }
    .padding(24)
    .background(Theme.background)
}
