import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ActivityView: View {
    @State private var notes: [UserNotification] = []
    @State private var listener: ListenerRegistration?

    var body: some View {
        List {
            if notes.isEmpty {
                Text("No activity yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(notes) { n in NotificationRow(note: n) }
            }
        }
        .navigationTitle("Activity")
        .listStyle(.plain)
        .onAppear(perform: attach)
        .onDisappear { listener?.remove(); listener = nil }
    }

    private func attach() {
        guard listener == nil, let uid = Auth.auth().currentUser?.uid else { return }
        listener = NetworkService.shared.observeNotifications(for: uid) { list in
            notes = list
        }
    }
}

private struct NotificationRow: View {
    let note: UserNotification

    @State private var post: Post? = nil
    @State private var isLoadingPost = false
    @State private var showProfile = false
    @State private var showPost    = false

    private var message: String {
        switch note.kind {
        case .mention: return "mentioned you"
        case .comment: return "commented on your post"
        case .like:    return "liked your post"
        case .tag:     return "tagged you in a post"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { showProfile = true } label: {
                AsyncImage(url: URL(string: note.fromAvatarURL ?? "")) { phase in
                    if let img = phase.image { img.resizable() } else { Color.gray.opacity(0.3) }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(note.fromUsername) \(message)")
                    .font(.subheadline)
                if note.kind != .like {
                    Text(note.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)

            if let post = post {
                Button { showPost = true } label: {
                    PostCell(post: post)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
            } else if isLoadingPost {
                ProgressView()
                    .frame(width: 48, height: 48)
            } else {
                Color.clear
                    .frame(width: 48, height: 48)
                    .onAppear(perform: fetchPost)
            }
        }
        .background {
            NavigationLink(destination: ProfileView(userId: note.fromUserId),
                           isActive: $showProfile) { EmptyView() }.hidden()
            if let p = post {
                NavigationLink(destination: PostDetailView(post: p),
                               isActive: $showPost) { EmptyView() }.hidden()
            }
        }
    }

    private func fetchPost() {
        guard !isLoadingPost else { return }
        isLoadingPost = true
        NetworkService.shared.fetchPost(id: note.postId) { result in
            switch result {
            case .success(let p):
                DispatchQueue.main.async { post = p }
            case .failure:
                if let uid = Auth.auth().currentUser?.uid {
                    NetworkService.shared.deleteNotification(userId: uid,
                                                           notificationId: note.id) { _ in }
                }
            }
            isLoadingPost = false
        }
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
    }
}
