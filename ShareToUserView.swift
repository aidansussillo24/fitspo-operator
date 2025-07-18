import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// A simple model for each “followed” user
private struct UserRow: Identifiable {
    let id: String
    let displayName: String
    let avatarURL: String
}

struct ShareToUserView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void

    @State private var rows: [UserRow] = []
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
                else if let errorMsg {
                    Text(errorMsg).foregroundColor(.red)
                }
                else {
                    ForEach(rows) { user in
                        Button {
                            onSelect(user.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                // Avatar
                                if let url = URL(string: user.avatarURL),
                                   !user.avatarURL.isEmpty
                                {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty: ProgressView()
                                        case .success(let img): img.resizable().scaledToFill()
                                        case .failure: Image(systemName: "person.crop.circle.fill").resizable()
                                        @unknown default: EmptyView()
                                        }
                                    }
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                            Text(user.displayName)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Share to…")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: fetchFollowing)
        }
    }

    private func fetchFollowing() {
        guard !isLoading,
              let me = Auth.auth().currentUser?.uid
        else { return }
        isLoading = true
        let db = Firestore.firestore()
        // ← adjust this path if your “following” is stored elsewhere
        db.collection("users")
          .document(me)
          .collection("following")
          .getDocuments { snap, err in
            isLoading = false
            if let err = err {
                errorMsg = err.localizedDescription
            } else {
                let ids = snap?.documents.map{ $0.documentID } ?? []
                fetchProfiles(for: ids)
            }
        }
    }

    private func fetchProfiles(for ids: [String]) {
        let db = Firestore.firestore()
        var temp: [UserRow] = []
        let group = DispatchGroup()
        for id in ids {
            group.enter()
            db.collection("users").document(id).getDocument { snap, err in
                defer { group.leave() }
                guard err == nil, let d = snap?.data() else { return }
                let name = d["displayName"] as? String ?? "Unknown"
                let avatar = d["avatarURL"] as? String ?? ""
                temp.append(UserRow(id: id, displayName: name, avatarURL: avatar))
            }
        }
        group.notify(queue: .main) {
            rows = temp.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        }
    }
}
