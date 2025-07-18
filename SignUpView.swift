//  Replace file: SignUpView.swift
//  FitSpo
//
//  Adds username-format validation (letters & numbers only, 3-24 chars).
//  Shows an inline error and disables the “Sign Up” button until the
//  username, email, and password all pass validation.

import SwiftUI

struct SignUpView: View {

    // MARK: – Form fields
    @State private var email:       String = ""
    @State private var password:    String = ""
    @State private var displayName: String = ""
    @State private var username:    String = ""

    // MARK: – UI state
    @State private var isLoading   = false
    @State private var errorMsg:   String?

    // MARK: – Regex helpers
    private let usernamePattern = "^[A-Za-z0-9]{3,24}$"
    private var usernameIsValid: Bool {
        NSPredicate(format: "SELF MATCHES %@", usernamePattern)
            .evaluate(with: username)
    }
    private var passwordIsValid: Bool { password.count >= 6 }
    private var emailIsValid:    Bool { email.contains("@") }

    private var formIsValid: Bool {
        usernameIsValid && passwordIsValid && emailIsValid
    }

    var body: some View {
        VStack(spacing: 16) {

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            SecureField("Password (min 6)", text: $password)
                .textFieldStyle(.roundedBorder)

            TextField("Display Name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            TextField("Username (letters & numbers only)",
                      text: $username)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
                .overlay(alignment: .trailing) {
                    if !username.isEmpty {
                        Image(systemName: usernameIsValid
                              ? "checkmark.circle.fill"
                              : "xmark.octagon.fill")
                            .foregroundColor(usernameIsValid
                                             ? .green : .red)
                            .padding(.trailing, 8)
                    }
                }

            if let err = errorMsg {
                Text(err)
                    .foregroundColor(.red)
            }

            Button {
                Task { await signUp() }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(!formIsValid || isLoading)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Create Account")
    }

    // MARK: – Sign-up logic
    private func signUp() async {
        errorMsg = nil
        guard formIsValid else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthViewModel.shared
                .createUser(email: email,
                            password: password,
                            displayName: displayName,
                            username: username)
            // success → dismiss view
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
