import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var user: FirebaseAuth.User?

    var body: some View {
        Group {
            if user == nil {
                AuthView()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            // listen for auth state changes
            _ = Auth.auth().addStateDidChangeListener { _, currentUser in
                self.user = currentUser
            }
        }
    }
}
