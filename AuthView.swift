
import SwiftUI

/// Swaps between Sign In and Sign Up screens
struct AuthView: View {
    @State private var isShowingSignUp = false

    var body: some View {
        NavigationStack {
            if isShowingSignUp {
                SignUpView()
                    .navigationTitle("Create Account")
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Already have an account? Sign In") {
                                isShowingSignUp = false
                            }
                        }
                    }
            } else {
                SignInView()
                    .navigationTitle("Sign In")
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("New here? Sign Up") {
                                isShowingSignUp = true
                            }
                        }
                    }
            }
        }
    }
}
