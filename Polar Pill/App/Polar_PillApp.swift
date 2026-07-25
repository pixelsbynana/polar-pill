//
//  Polar_PillApp.swift
//  Polar Pill
//
//  Medication support built for families.
//

import SwiftUI

@main
struct PolarPillApp: App {
    init() {
        // Handle notification banners + taps (missed-dose deep links).
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
