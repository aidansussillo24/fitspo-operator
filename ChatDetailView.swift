import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatDetailView: View {
    let chat: Chat

    @State private var messages: [Message] = []
    @State private var newText: String = ""
    @State private var listener: ListenerRegistration?
    @State private var profiles: [String:(displayName: String, avatarURL: String)] = [:]
    @State private var postCache: [String: Post] = [:]

    private var myUid: String { Auth.auth().currentUser?.uid ?? "" }
    private var otherUid: String { chat.participants.first { $0 != myUid } ?? "" }
    private var navTitle: String { profiles[otherUid]?.displayName ?? otherUid }

    var body: some View {
        VStack(spacing: 0) {
            // ─── Message list ───────────────────────────
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { msg in
                            HStack(alignment: .bottom, spacing: 8) {
                                // incoming: avatar + bubble on left
                                if msg.senderId != myUid {
                                    avatarView(userId: msg.senderId, size: 32)
                                    messageContent(for: msg, incoming: true)
                                    Spacer()
                                } else {
                                    // outgoing: bubble on right
                                    Spacer()
                                    messageContent(for: msg, incoming: false)
                                }
                            }
                            .padding(.horizontal, 12)
                            .id(msg.id)
                            .onAppear { loadProfile(userId: msg.senderId) }
                        }
                    }
                    .padding(.vertical, 12)
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // ─── Composer ───────────────────────────────
            HStack {
                TextField("Message…", text: $newText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send", action: sendText)
                    .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListening()
            loadProfile(userId: otherUid)
        }
        .onDisappear { listener?.remove() }
    }

    // MARK: – Message content (text or post thumbnail)
    @ViewBuilder
    private func messageContent(for msg: Message, incoming: Bool) -> some View {
        if let pid = msg.postId {
            sharedPostThumbnail(postId: pid)
        } else {
            Text(msg.text ?? "")
                .padding(10)
                .background(incoming
                            ? Color.gray.opacity(0.2)
                            : Color.black.opacity(0.8))
                .foregroundColor(incoming ? .primary : .white)
                .cornerRadius(12)
                .frame(maxWidth: 250, alignment: incoming ? .leading : .trailing)
        }
    }

    // MARK: – Avatar for incoming messages
    @ViewBuilder
    private func avatarView(userId: String, size: CGFloat) -> some View {
        if let p = profiles[userId],
           let url = URL(string: p.avatarURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:     ProgressView()
                case .success(let img): img.resizable().scaledToFill()
                case .failure:    Image(systemName: "person.crop.circle.fill").resizable()
                @unknown default: EmptyView()
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundColor(.gray)
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
    }

    // MARK: – Shared‐post thumbnail
    @ViewBuilder
    private func sharedPostThumbnail(postId: String) -> some View {
        if let post = postCache[postId] {
            NavigationLink(destination: PostDetailView(post: post)) {
                PostCardView(post: post, onLike: {})
                    .frame(width: 120, height: 120)
                    .cornerRadius(8)
            }
        } else {
            ProgressView()
                .frame(width: 120, height: 120)
                .onAppear { fetchPostIfNeeded(id: postId) }
        }
    }

    // MARK: – Firestore listener
    private func startListening() {
        let db = Firestore.firestore()
        listener = db
            .collection("chats").document(chat.id)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                messages = docs.compactMap { doc in
                    let d = doc.data()
                    guard let sid = d["senderId"] as? String,
                          let ts  = d["timestamp"]  as? Timestamp else { return nil }
                    return Message(
                        id:        doc.documentID,
                        senderId:  sid,
                        text:      d["text"]   as? String,
                        postId:    d["postId"] as? String,
                        timestamp: ts.dateValue()
                    )
                }
                // pre-fetch any new shared posts
                for m in messages where m.postId != nil {
                    fetchPostIfNeeded(id: m.postId!)
                }
            }
    }

    // MARK: – Sending a text message
    private func sendText() {
        let trimmed = newText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let me = Auth.auth().currentUser?.uid else { return }
        let db  = Firestore.firestore()
        let ref = db.collection("chats")
                    .document(chat.id)
                    .collection("messages")
                    .document()
        let data: [String:Any] = [
            "senderId":  me,
            "text":      trimmed,
            "timestamp": Timestamp(date: Date())
        ]
        ref.setData(data) { _ in
            db.collection("chats").document(chat.id).updateData([
                "lastMessage":   trimmed,
                "lastTimestamp": Timestamp(date: Date())
            ])
        }
        newText = ""
    }

    // MARK: – Fetch a single post for its thumbnail
    private func fetchPostIfNeeded(id pid: String) {
        NetworkService.shared.fetchPost(id: pid) { result in
            if case .success(let post) = result {
                DispatchQueue.main.async {
                    postCache[pid] = post
                }
            }
        }
    }

    // MARK: – Load a user’s profile
    private func loadProfile(userId: String) {
        guard profiles[userId] == nil else { return }
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .getDocument { snap, _ in
                if let data = snap?.data() {
                    let name   = data["displayName"] as? String ?? userId
                    let avatar = data["avatarURL"]   as? String ?? ""
                    DispatchQueue.main.async {
                        profiles[userId] = (displayName: name, avatarURL: avatar)
                    }
                }
            }
    }
}
