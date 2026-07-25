//
//  AuthViewModel.swift
//  Polar Pill
//
//  Email/password sign up + log in against Supabase Auth.
//

import Foundation
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    enum Mode: String, CaseIterable {
        case signUp = "Sign up"
        case logIn = "Log in"
    }

    var mode: Mode = .signUp
    var fullName = ""
    var email = ""
    var password = ""
    var isBusy = false
    var errorMessage: String?
    /// Set when sign-up succeeded but email confirmation is required.
    var awaitingEmailConfirmation = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        // Sign-up when arriving from onboarding, log-in for returning users.
        mode = appState.startAuthInLogIn ? .logIn : .signUp
    }

    func submit() async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        guard let client = SupabaseService.shared?.client else {
            errorMessage = "Supabase is not configured."
            return
        }

        do {
            switch mode {
            case .signUp:
                // full_name + role feed the handle_new_user trigger, which
                // creates the profiles row server-side.
                let response = try await client.auth.signUp(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    data: [
                        "full_name": .string(fullName.trimmingCharacters(in: .whitespaces)),
                        "role": .string(appState.draftRole.rawValue),
                    ]
                )
                if let session = response.session {
                    await appState.handleAuthenticated(userID: session.user.id)
                } else {
                    // Email confirmation is enabled on the Supabase project.
                    awaitingEmailConfirmation = true
                }
            case .logIn:
                let session = try await client.auth.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                await appState.handleAuthenticated(userID: session.user.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canSubmit: Bool {
        let hasCredentials = !email.isEmpty && password.count >= 6
        return mode == .logIn ? hasCredentials : hasCredentials && !fullName.isEmpty
    }
}
