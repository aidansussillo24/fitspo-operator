// FollowersView.swift

import SwiftUI
import FirebaseFirestore

/// Simple struct for each user in the list.
private struct ProfileItem: Identifiable {
    let id: String
    let displayName: String
    let avatarURL: String?
}

struct FollowersView: View {
    let userId: String

    @State private var followers: [ProfileItem] = []
    @State private var isLoading   = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
            else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            else {
                ForEach(followers) { user in
                    HStack(spacing: 12) {
                        if let urlString = user.avatarURL,
                           let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty: ProgressView()
                                case .success(let img):
                                    img.resizable()
                                       .aspectRatio(contentMode: .fill)
                                case .failure:
                                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                                        .resizable()
                                        .scaledToFit()
                                @unknown default: EmptyView()
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                        }

                        Text(user.displayName)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Followers")
        .refreshable {
            await loadList(from: "followers")
        }
        .task {
            await loadList(from: "followers")
        }
    }

    private func loadList(from collectionName: String) async {
        isLoading     = true
        errorMessage  = nil
        followers     = []

        let db = Firestore.firestore()
        do {
            // 1) get the IDs in the sub-collection
            let snap = try await db
                .collection("users")
                .document(userId)
                .collection(collectionName)
                .getDocuments()
            let ids = snap.documents.map(\.documentID)

            // 2) fetch each user profile doc
            var loaded: [ProfileItem] = []
            for id in ids {
                let doc = try await db
                    .collection("users")
                    .document(id)
                    .getDocument()
                guard let data = doc.data() else { continue }
                let name   = data["displayName"] as? String ?? "No Name"
                let avatar = data["avatarURL"]   as? String
                loaded.append(.init(id: id, displayName: name, avatarURL: avatar))
            }

            // 3) sort (alphabetical)
            followers = loaded.sorted { $0.displayName < $1.displayName }
        }
        catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct FollowersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FollowersView(userId: "dummyUserID")
        }
    }
}
