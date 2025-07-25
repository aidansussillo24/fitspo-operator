//
//  CommentsOverlay.swift
//  FitSpo
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommentsOverlay: View {
    let post: Post
    @Binding var isPresented: Bool
    var onCommentCountChange: (Int) -> Void
    var onHashtagTap: ((String) -> Void)? = nil
    var onMentionTap: ((String) -> Void)? = nil

    @State private var comments: [Comment] = []
    @State private var newText  = ""
    @FocusState private var isInputActive: Bool

    // edit state
    @State private var editingId: String?
    @State private var editText = ""

    @State private var dragOffset: CGFloat = 0
    @State private var listener: ListenerRegistration?
    @StateObject private var kb = KeyboardResponder()
    
    // User profile for input bar
    @State private var currentUserAvatar: String = ""

    private var myUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        VStack(spacing: 0) {
            header
            list
            inputBar
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.65, alignment: .top)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .offset(y: dragOffset)
        .padding(.bottom, kb.height)
        .gesture(
            DragGesture()
                .onChanged { v in 
                    if v.translation.height > 0 { 
                        dragOffset = v.translation.height
                        // Dismiss keyboard immediately when swiping down
                        if v.translation.height > 50 {
                            isInputActive = false
                        }
                    }
                }
                .onEnded { v in 
                    if v.translation.height > 100 { 
                        isInputActive = false // Ensure keyboard is dismissed
                        isPresented = false 
                    }
                    dragOffset = 0 
                }
        )
        .onAppear {
            attachListener()
            loadCurrentUserProfile()
        }
        .onDisappear { 
            listener?.remove() 
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut, value: dragOffset)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    }

    // MARK: header
    private var header: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            Text("Comments").font(.headline)
            Divider()
        }
    }

    // MARK: comment list
    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(comments) { c in
                        CommentRow(
                            comment: c,
                            isMe: c.userId == myUid,
                            onEdit: { beginEdit(c) },
                            onDelete: { deleteComment(c) },
                            onHashtagTap: { hashtag in
                                onHashtagTap?(hashtag)
                            },
                            onMentionTap: { username in
                                onMentionTap?(username)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.top, 6)
            }
            .onChange(of: comments.count) { _ in
                if let last = comments.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    // MARK: input / edit bar
    private var inputBar: some View {
        VStack(spacing: 8) {
            if let editingId = editingId {
                HStack(spacing: 12) {
                    // User's profile image
                    AsyncImage(url: URL(string: currentUserAvatar)) { phase in
                        if let img = phase.image { 
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else { 
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    TextField("Edit comment", text: $editText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isInputActive)
                    
                    VStack(spacing: 4) {
                        Button("Save") { commitEdit(id: editingId) }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                        Button("Cancel") { cancelEdit() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    // User's profile image
                    AsyncImage(url: URL(string: currentUserAvatar)) { phase in
                        if let img = phase.image { 
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else { 
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    TextField("Add a comment…", text: $newText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isInputActive)
                    
                    Button {
                        sendComment()
                    } label: {
                        Text("Post")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
                    }
                    .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
            , alignment: .top
        )
    }

    // MARK: Firestore listener
    private func attachListener() {
        guard listener == nil else { return }
        listener = Firestore.firestore()
            .collection("posts").document(post.id)
            .collection("comments")
            .order(by: "timestamp")
            .addSnapshotListener { snap, _ in
                comments = snap?.documents.compactMap { Comment(from: $0.data()) } ?? []
                onCommentCountChange(comments.count)
            }
    }

    // MARK: send new comment
    private func sendComment() {
        let txt = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !txt.isEmpty, let uid = myUid else { return }
        newText = ""; isInputActive = false

        let c = Comment(
            postId: post.id,
            userId: uid,
            username: Auth.auth().currentUser?.displayName ?? "User",
            userPhotoURL: Auth.auth().currentUser?.photoURL?.absoluteString,
            text: txt
        )
        NetworkService.shared.addComment(to: post.id, comment: c) { _ in
            NetworkService.shared.handleCommentNotifications(postOwnerId: post.userId, comment: c)
        }
    }

    // MARK: edit helpers
    private func beginEdit(_ c: Comment) {
        editingId = c.id
        editText  = c.text
        isInputActive = true
    }

    private func cancelEdit() {
        editingId = nil
        editText  = ""
        isInputActive = false
    }

    private func commitEdit(id: String) {
        let txt = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !txt.isEmpty else { cancelEdit(); return }
        NetworkService.shared.updateComment(postId: post.id, commentId: id, newText: txt) { _ in }
        cancelEdit()
    }

    // MARK: delete helper
    private func deleteComment(_ c: Comment) {
        NetworkService.shared.deleteComment(postId: post.id, commentId: c.id) { _ in }
    }

    private func loadCurrentUserProfile() {
        guard let uid = myUid else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { snap, _ in
            if let data = snap?.data() {
                self.currentUserAvatar = data["avatarURL"] as? String ?? ""
            }
        }
    }
}

// MARK: – Single comment row
private struct CommentRow: View {
    let comment: Comment
    let isMe: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onHashtagTap: (String) -> Void
    var onMentionTap: (String) -> Void

    @State private var name: String = ""
    @State private var avatar: String?
    @State private var isLiked: Bool = false

    private static var cache: [String:(String,String?)] = [:]
    private var myUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Image
            AsyncImage(url: URL(string: avatar ?? comment.userPhotoURL ?? "")) { phase in
                if let img = phase.image {
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Username and comment text in one line (Instagram style)
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 4) {
                            Text(name.isEmpty ? comment.username : name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)

                            ClickableHashtagText(text: comment.text) { hashtag in
                                onHashtagTap(hashtag)
                            } onMentionTap: { username in
                                onMentionTap(username)
                            }
                            .font(.system(size: 13))
                            .lineLimit(nil)
                        }

                        // Action buttons (timestamp, like, reply)
                        HStack(spacing: 16) {
                            Text(comment.timeAgo)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount) \(comment.likeCount == 1 ? "like" : "likes")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }

                            Button("Reply") {
                                // TODO: Implement reply functionality
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                            Spacer()
                        }
                        .padding(.top, 2)
                    }

                    Spacer()

                    // Like button (heart)
                    Button {
                        toggleLike()
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundColor(isLiked ? .red : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            ensureProfile()
            checkIfLiked()
        }
        .contextMenu {
            if isMe {
                Button("Edit", action: onEdit)
                Button(role: .destructive, action: onDelete) { Text("Delete") }
            }
        }
    }

    private func ensureProfile() {
        if let cached = CommentRow.cache[comment.userId] {
            name = cached.0; avatar = cached.1; return
        }
        if comment.username != "User", comment.userPhotoURL != nil {
            CommentRow.cache[comment.userId] =
                (comment.username, comment.userPhotoURL)
            return
        }
        Firestore.firestore().collection("users").document(comment.userId)
            .getDocument { snap, _ in
                let d = snap?.data() ?? [:]
                let n = d["displayName"] as? String ?? "User"
                let a = d["avatarURL"]   as? String
                CommentRow.cache[comment.userId] = (n, a)
                name = n; avatar = a
            }
    }

    private func checkIfLiked() {
        guard let uid = myUid else { return }
        isLiked = comment.likedBy.contains(uid)
    }

    private func toggleLike() {
        guard let uid = myUid else { return }

        if isLiked {
            NetworkService.shared.unlikeComment(
                postId: comment.postId,
                commentId: comment.id,
                userId: uid
            ) { _ in }
        } else {
            NetworkService.shared.likeComment(
                postId: comment.postId,
                commentId: comment.id,
                userId: uid
            ) { _ in }
        }

        isLiked.toggle()
    }
}
