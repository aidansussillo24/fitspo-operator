import SwiftUI
import FirebaseFirestore

enum FollowType {
    case followers, following
}

struct FollowListView: View {
    let userId: String
    let type: FollowType

    @State private var userProfiles: [UserProfile] = []
    @State private var isLoading = false
    @State private var errorMsg: String?

    private let db = Firestore.firestore()

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else if let error = errorMsg {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            else {
                List(userProfiles) { profile in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: profile.avatarURL)) { phase in
                            if let img = phase.image {
                                img.resizable()
                                   .scaledToFill()
                                   .frame(width: 44, height: 44)
                                   .clipShape(Circle())
                            } else {
                                Circle()
                                  .fill(Color.gray.opacity(0.3))
                                  .frame(width: 44, height: 44)
                            }
                        }
                        Text(profile.displayName)
                        Spacer()
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(type == .followers ? "Followers" : "Following")
        .task { await loadList() }
    }

    private func loadList() async {
        isLoading = true
        errorMsg = nil
        let collection = type == .followers ? "followers" : "following"

        do {
            let snap = try await db
                .collection("users")
                .document(userId)
                .collection(collection)
                .getDocuments()
            let ids = snap.documents.map { $0.documentID }

            // Fetch each user's profile in parallel
            let profiles = try await withThrowingTaskGroup(of: UserProfile?.self) { group in
                for id in ids {
                    group.addTask {
                        let doc = try await db
                            .collection("users")
                            .document(id)
                            .getDocument()
                        guard let data = doc.data() else { return nil }
                        return UserProfile(
                            id: id,
                            displayName: data["displayName"] as? String ?? "Unknown",
                            avatarURL:   data["avatarURL"]   as? String ?? ""
                        )
                    }
                }

                var results = [UserProfile]()
                for try await maybe in group {
                    if let profile = maybe {
                        results.append(profile)
                    }
                }
                return results
            }

            userProfiles = profiles
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}

// A simple model for listing
struct UserProfile: Identifiable {
    let id: String
    let displayName: String
    let avatarURL: String
}
