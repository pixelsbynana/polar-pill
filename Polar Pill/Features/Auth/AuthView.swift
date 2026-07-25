//
//  AuthView.swift
//  Polar Pill
//
//  Simple email/password auth (not in the mockups, styled to match).
//

import SwiftUI

struct AuthView: View {
    let appState: AppState
    @State private var viewModel: AuthViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: AuthViewModel(appState: appState))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Back to the welcome screen.
                    HStack {
                        Button {
                            appState.backToWelcome()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.title3)
                                .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                        Spacer()
                    }

                    Image("Mascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)

                    // The mode is fixed by the welcome screen's choice —
                    // no sign-up/log-in toggle here.
                    Text(viewModel.mode == .signUp ? "Create your account" : "Welcome back")
                        .font(.title2.bold())

                    if viewModel.awaitingEmailConfirmation {
                        confirmationNotice
                    } else {
                        fields
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .multilineTextAlignment(.center)
                    }

                    if viewModel.isBusy {
                        ProgressView()
                            .padding(.top, 4)
                    } else if !viewModel.awaitingEmailConfirmation {
                        PrimaryButton(title: viewModel.mode.rawValue) {
                            Task { await viewModel.submit() }
                        }
                        .opacity(viewModel.canSubmit ? 1 : 0.5)
                        .disabled(!viewModel.canSubmit)
                    }
                }
                .padding(24)
            }
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            if viewModel.mode == .signUp {
                authTextField("Full name", text: $viewModel.fullName)
                    .textContentType(.name)
            }
            authTextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password (6+ characters)", text: $viewModel.password)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    private func authTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }

    private var confirmationNotice: some View {
        VStack(spacing: 8) {
            Image(systemName: "envelope.badge")
                .font(.largeTitle)
                .foregroundStyle(Theme.primary)
            Text("Check your email")
                .font(.headline)
            Text("We sent a confirmation link to \(viewModel.email). Confirm it, then come back and log in.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            SecondaryButton(title: "Back to log in") {
                viewModel.awaitingEmailConfirmation = false
                viewModel.mode = .logIn
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

#Preview {
    AuthView(appState: AppState())
}
