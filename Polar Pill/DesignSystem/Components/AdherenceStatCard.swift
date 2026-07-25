//
//  AdherenceStatCard.swift
//  Polar Pill
//
//  "18/21 doses taken this week" stat card with trend icon, from the
//  patient detail mockup.
//

import SwiftUI

struct AdherenceStatCard: View {
    let taken: Int
    let scheduled: Int
    var caption: String = "doses taken this week"

    var body: some View {
        HStack(spacing: 12) {
            Text("\(taken)/\(scheduled)")
                .font(.largeTitle.bold()) // scales with Dynamic Type
                .foregroundStyle(Theme.navy)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(Theme.primary)
                .font(.title3)
                .accessibilityHidden(true)
        }
        .padding(18)
        .background(Theme.primaryTint, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.primary.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(taken) of \(scheduled) \(caption)")
    }
}

#Preview {
    AdherenceStatCard(taken: 18, scheduled: 21)
        .padding()
        .background(Theme.background)
}
