//
//  Theme.swift
//  Polar Pill
//
//  Design-system palette and typography matching the mockups.
//

import SwiftUI

enum Theme {
    // MARK: - Palette

    /// Soft off-white app background.
    static let background = Color(hex: 0xECECE9)
    /// Card surfaces.
    static let card = Color.white
    /// Subtle card border.
    static let cardBorder = Color(hex: 0xD9D9D6)
    /// Muted steel blue — primary buttons, active tabs, "Taken" badges.
    static let primary = Color(hex: 0x6E88A8)
    /// Light blue tint used for the Next Dose card and adherence stat card.
    static let primaryTint = Color(hex: 0xEDF3F9)
    /// Danger red — "Missed" badge outline/text only, used sparingly.
    static let danger = Color(hex: 0xC0392B)
    /// Dark navy — celebratory confirmation screen and report header.
    static let navy = Color(hex: 0x141C2E)
    /// Muted secondary text.
    static let secondaryText = Color(hex: 0x8A8A8E)
    /// Darker secondary text for patient-facing details (dose, time) that
    /// elderly users must read clearly.
    static let strongSecondaryText = Color(hex: 0x48484C)
    /// Neutral gray for missed days in the weekly bar chart.
    static let chartGray = Color(hex: 0xC7C7CC)

    // MARK: - Metrics

    /// Standard card corner radius from the mockups (~16–20pt).
    static let cornerRadius: CGFloat = 18
    /// Minimum tap target for elderly users.
    static let minTapTarget: CGFloat = 44
}

extension Color {
    /// Creates a Color from a 24-bit hex value, e.g. Color(hex: 0x6E88A8).
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
