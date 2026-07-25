//
//  RootView.swift
//  Polar Pill
//
//  Top-level router: onboarding → auth → role-appropriate home.
//

import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        Group {
            if !AppConfig.isConfigured {
                notConfigured
            } else {
                switch appState.phase {
                case .loading:
                    splash
                case .onboarding:
                    OnboardingView(appState: appState)
                case .auth:
                    AuthView(appState: appState)
                case .patientHome:
                    PatientHomeView(appState: appState)
                case .caregiverHome:
                    CaregiverTabView(appState: appState)
                }
            }
        }
        .task { await appState.start() }
    }

    private var splash: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Text("Polar Pill")
                    .font(.largeTitle.bold())
                Text("Medication support built for families.")
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var notConfigured: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Text("Polar Pill")
                    .font(.largeTitle.bold())
                Text("Medication support built for families.")
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                // Developer-facing notice shown only while Config.xcconfig has placeholders.
                Text("Supabase is not configured yet.\nAdd your project URL and anon key to Config/Config.xcconfig.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    RootView()
}
