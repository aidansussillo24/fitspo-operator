import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var bio         = ""
    @State private var avatarImage: UIImage?
    @State private var avatarURL   = ""      // existing URL
    @State private var showImagePicker = false
    @State private var isLoading       = false
    @State private var errorMessage    = ""

    private let db      = Firestore.firestore()
    private let storage = Storage.storage().reference()
    private var userId: String { Auth.auth().currentUser?.uid ?? "" }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Avatar")) {
                    HStack {
                        Spacer()
                        Button {
                            showImagePicker = true
                        } label: {
                            if let img = avatarImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let url = URL(string: avatarURL), !avatarURL.isEmpty {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable()
                                           .scaledToFill()
                                           .frame(width: 100, height: 100)
                                           .clipShape(Circle())
                                    } else {
                                        Circle()
                                          .fill(Color.gray.opacity(0.3))
                                          .frame(width: 100, height: 100)
                                          .overlay(Image(systemName: "camera").font(.title2))
                                    }
                                }
                            } else {
                                Circle()
                                  .fill(Color.gray.opacity(0.3))
                                  .frame(width: 100, height: 100)
                                  .overlay(Image(systemName: "camera").font(.title2))
                            }
                        }
                        Spacer()
                    }
                }

                Section(header: Text("Name & Bio")) {
                    TextField("Display Name", text: $displayName)
                    TextField("Bio", text: $bio)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: saveProfile)
                        .disabled(displayName.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $avatarImage)
            }
            .onAppear(perform: loadCurrentProfile)
        }
    }

    private func loadCurrentProfile() {
        guard !userId.isEmpty else { return }
        db.collection("users").document(userId).getDocument { snap, err in
            if let err = err {
                errorMessage = err.localizedDescription
                return
            }
            let data = snap?.data() ?? [:]
            displayName = data["displayName"] as? String ?? ""
            bio         = data["bio"]         as? String ?? ""
            avatarURL   = data["avatarURL"]   as? String ?? ""
        }
    }

    private func saveProfile() {
        guard !userId.isEmpty else { return }
        isLoading    = true
        errorMessage = ""

        // 1) If user picked a new image, upload it first
        if let newImage = avatarImage,
           let jpegData = newImage.jpegData(compressionQuality: 0.8) {
            let ref = storage.child("avatars/\(userId).jpg")
            ref.putData(jpegData, metadata: nil) { _, err in
                if let err = err {
                    fail(err.localizedDescription)
                } else {
                    ref.downloadURL { url, err in
                        if let err = err {
                            fail(err.localizedDescription)
                        } else {
                            updateUserDoc(avatarURL: url?.absoluteString)
                        }
                    }
                }
            }
        } else {
            // 2) No new avatar, just update text fields
            updateUserDoc(avatarURL: avatarURL)
        }
    }

    private func updateUserDoc(avatarURL: String?) {
        var data: [String: Any] = [
            "displayName": displayName,
            "bio":         bio
        ]
        if let avatarURL = avatarURL {
            data["avatarURL"] = avatarURL
        }

        db.collection("users").document(userId).updateData(data) { err in
            if let err = err {
                fail(err.localizedDescription)
            } else {
                isLoading = false
                dismiss()
            }
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        isLoading    = false
    }
}
