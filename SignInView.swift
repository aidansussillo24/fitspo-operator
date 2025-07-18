import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @State private var email        = ""
    @State private var password     = ""
    @State private var errorMessage: String?
    @State private var isLoading    = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                signIn()
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)

            Spacer()
        }
        .padding()
    }

    private func signIn() {
        isLoading    = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { result, authError in
            isLoading = false
            if let authError = authError {
                self.errorMessage = authError.localizedDescription
            } else {
                dismiss()
            }
        }
    }
}
