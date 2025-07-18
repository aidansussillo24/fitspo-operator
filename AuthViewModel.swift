//  Replace file: AuthViewModel.swift
//  FitSpo
//
//  Fixes type clashes with custom `User` model and uses proper
//  Firebase `createProfileChangeRequest()` to set displayName.
//  Provides createUser/signIn/signOut methods.

import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

    static let shared = AuthViewModel()
    private init() {
        self.currentUser = Auth.auth().currentUser
        Auth.auth().addStateDidChangeListener { _, user in
            self.currentUser = user
        }
    }

    /// FirebaseAuth.User so it doesn’t collide with your own `User` model
    @Published var currentUser: FirebaseAuth.User?

    // MARK: – Create account + profile ---------------------------
    func createUser(email: String,
                    password: String,
                    displayName: String,
                    username: String) async throws {
        let auth = Auth.auth()
        let result = try await auth.createUser(withEmail: email,
                                               password: password)

        // set display name via profile change request
        let change = result.user.createProfileChangeRequest()
        change.displayName = displayName
        try await change.commitChanges()

        // build Firestore profile data
        let profile: [String:Any] = [
            "displayName": displayName,
            "username"   : username,
            "avatarURL"  : ""
        ]
        try await NetworkService.shared
            .createUserProfile(userId: result.user.uid,
                               data: profile)
    }

    // MARK: – Sign-in  ------------------------------------------
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    // MARK: – Sign-out ------------------------------------------
    func signOut() throws {
        try Auth.auth().signOut()
    }
}

//  End of file
