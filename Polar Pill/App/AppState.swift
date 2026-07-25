//
//  AppState.swift
//  Polar Pill
//
//  Top-level session/routing state (MVVM: view models talk to services,
//  AppState decides which experience is shown).
//

import Foundation
import Supabase

@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        /// Checking for an existing session at launch.
        case loading
        /// Welcome + role selection + family setup (single mockup screen).
        case onboarding
        /// Sign up / log in.
        case auth
        /// Signed in as a patient.
        case patientHome
        /// Signed in as a caregiver.
        case caregiverHome
    }

    var phase: Phase = .loading
    var profile: Profile?

    // Draft collected during onboarding, persisted after authentication.
    var draftRole: UserRole = .patient
    var draftMembers: [DraftFamilyMember] = []
    var draftInviteCode: String = ""
    /// True when the user came through onboarding (i.e. is signing UP and
    /// we still need to create their family after auth).
    private var hasPendingOnboarding = false
    /// Whether the auth screen should open in log-in mode (returning users)
    /// instead of sign-up.
    var startAuthInLogIn = false

    private var service: OnboardingService? {
        SupabaseService.shared.map { OnboardingService(client: $0.client) }
    }

    // MARK: - Launch

    func start() async {
        guard let client = SupabaseService.shared?.client else {
            phase = .onboarding // unconfigured builds still show the UI
            return
        }
        if let session = client.auth.currentSession {
            await routeSignedIn(userID: session.user.id)
        } else {
            phase = .onboarding
        }
    }

    // MARK: - Onboarding

    func continueFromOnboarding() async {
        // Spec: request notification permission right after role selection.
        await NotificationManager.requestPermission()
        hasPendingOnboarding = true
        startAuthInLogIn = false
        phase = .auth
    }

    /// "Log in" from the welcome screen — returning users skip the
    /// role/family setup entirely.
    func goToLogIn() {
        hasPendingOnboarding = false
        startAuthInLogIn = true
        phase = .auth
    }

    /// Back from the auth screen to the welcome screen.
    func backToWelcome() {
        hasPendingOnboarding = false
        startAuthInLogIn = false
        phase = .onboarding
    }

    // MARK: - Auth callbacks

    /// Called by AuthViewModel once a session exists.
    /// Pending onboarding is finalized regardless of sign-up vs log-in: with
    /// email confirmation enabled, users sign up, confirm, then LOG in — the
    /// family still needs to be created on that first login.
    func handleAuthenticated(userID: UUID) async {
        guard let service else { return }
        if hasPendingOnboarding {
            do {
                if !draftInviteCode.isEmpty {
                    // Joining an existing family instead of creating one.
                    try await service.acceptInvite(code: draftInviteCode.trimmingCharacters(in: .whitespaces))
                } else {
                    _ = try await service.finalizeOnboarding(userID: userID, draftMembers: draftMembers)
                }
            } catch {
                // Family setup can be retried from Settings later; don't block sign-in.
                print("Onboarding finalization failed: \(error)")
            }
            hasPendingOnboarding = false
        }
        await routeSignedIn(userID: userID)
    }

    private func routeSignedIn(userID: UUID) async {
        guard let service else { return }
        do {
            let profile = try await service.fetchProfile(userID: userID)
            self.profile = profile
            phase = profile.role == .patient ? .patientHome : .caregiverHome
        } catch {
            // Profile row missing/unreachable — fall back to onboarding.
            print("Failed to load profile: \(error)")
            phase = .onboarding
        }
    }

    // MARK: - Sign out

    func signOut() async {
        try? await SupabaseService.shared?.client.auth.signOut()
        profile = nil
        draftMembers = []
        draftInviteCode = ""
        phase = .onboarding
    }
}
