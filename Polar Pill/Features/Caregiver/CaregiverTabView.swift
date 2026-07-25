//
//  CaregiverTabView.swift
//  Polar Pill
//
//  Caregiver root: Home / Reports / Settings tab bar from the mockups.
//

import SwiftUI

struct CaregiverTabView: View {
    let appState: AppState
    @State private var viewModel: DashboardViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: DashboardViewModel(currentProfileID: appState.profile?.id))
    }

    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem { Label("Home", systemImage: "house") }

            ReportsView(dashboard: viewModel)
                .tabItem { Label("Reports", systemImage: "doc.text") }

            SettingsView(appState: appState, viewModel: viewModel)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.primary)
    }
}
