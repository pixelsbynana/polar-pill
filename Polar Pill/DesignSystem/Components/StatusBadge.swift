//
//  StatusBadge.swift
//  Polar Pill
//
//  Pill-shaped Taken / Missed / Later badge from the mockups.
//  Distinguished by text + color (never color alone).
//

import SwiftUI

enum DoseDisplayStatus {
    case taken
    case missed
    case later

    init(logStatus: DoseStatus?) {
        switch logStatus {
        case .taken: self = .taken
        case .missed: self = .missed
        case .pending, nil: self = .later
        }
    }

    var label: String {
        switch self {
        case .taken: "Taken"
        case .missed: "Missed"
        case .later: "Later"
        }
    }
}

struct StatusBadge: View {
    let status: DoseDisplayStatus

    var body: some View {
        Text(status.label)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
            .foregroundStyle(foreground)
            .accessibilityLabel("Status: \(status.label)")
    }

    private var background: Color {
        switch status {
        case .taken: Theme.primary
        case .missed, .later: Theme.card
        }
    }

    private var foreground: Color {
        switch status {
        case .taken: .white
        case .missed: Theme.danger
        case .later: Theme.secondaryText
        }
    }

    private var border: Color {
        switch status {
        case .taken: .clear
        case .missed: Theme.danger
        case .later: Theme.cardBorder
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusBadge(status: .taken)
        StatusBadge(status: .missed)
        StatusBadge(status: .later)
    }
    .padding()
    .background(Theme.background)
}
