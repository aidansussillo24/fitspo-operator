// MessagesView.swift

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MessagesView: View {
    @State private var chats: [Chat] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // cache displayName+avatar per userId
    @State private var profiles: [String: (displayName: String, avatarURL: String)] = [:]

    var body: some View {
        NavigationView {
            Group {
                // 1) loading spinner
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 2) error + retry
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") { loadChats(force: true) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 3) chat list
                } else {
                    List(chats) { chat in
                        let otherId = chat.participants.first { $0 != Auth.auth().currentUser?.uid } ?? ""
                        NavigationLink(destination: ChatDetailView(chat: chat)) {
                            HStack(spacing: 12) {
                                avatarView(userId: otherId)
                                    .onAppear { loadProfile(userId: otherId) }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profiles[otherId]?.displayName ?? otherId)
                                        .font(.headline)
                                    Text(chat.lastMessage)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .navigationTitle("Messages")
        }
        .onAppear { loadChats() }
    }

    @ViewBuilder
    private func avatarView(userId: String) -> some View {
        if let profile = profiles[userId],
           let url = URL(string: profile.avatarURL)
        {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:     ProgressView()
                case .success(let img): img.resizable().scaledToFill()
                case .failure:    Image(systemName: "person.crop.circle.fill").resizable()
                @unknown default: EmptyView()
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
                .clipShape(Circle())
        }
    }

    private func loadChats(force: Bool = false) {
        guard !isLoading, force || chats.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        NetworkService.shared.fetchChats { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fetched):
                    self.chats = fetched
                case .failure(let err):
                    self.errorMessage = err.localizedDescription
                }
            }
        }
    }

    private func loadProfile(userId: String) {
        guard profiles[userId] == nil else { return }
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .getDocument { snap, err in
                guard err == nil, let d = snap?.data() else { return }
                let name   = d["displayName"] as? String ?? ""
                let avatar = d["avatarURL"]   as? String ?? ""
                DispatchQueue.main.async {
                    profiles[userId] = (displayName: name, avatarURL: avatar)
                }
            }
    }
}

struct MessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MessagesView()
    }
}
