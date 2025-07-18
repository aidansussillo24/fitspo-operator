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

    @State private var comments: [Comment] = []
    @State private var newText  = ""
    @FocusState private var isInputActive: Bool

    // edit state
    @State private var editingId: String?
    @State private var editText = ""

    @State private var dragOffset: CGFloat = 0
    @State private var listener: ListenerRegistration?
    @StateObject private var kb = KeyboardResponder()

    private var myUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        VStack(spacing: 0) {
            header
            list
            inputBar
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.65, alignment: .top)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .offset(y: dragOffset)
        .padding(.bottom, kb.height)
        .gesture(
            DragGesture()
                .onChanged { v in if v.translation.height > 0 { dragOffset = v.translation.height } }
                .onEnded   { v in if v.translation.height > 100 { isPresented = false }; dragOffset = 0 }
        )
        .onAppear { attachListener() }
        .onDisappear { listener?.remove() }
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut, value: dragOffset)
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
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(comments) { c in
                        CommentRow(
                            comment: c,
                            isMe: c.userId == myUid,
                            onEdit: { beginEdit(c) },
                            onDelete: { deleteComment(c) }
                        )
                    }
                }
                .padding(.horizontal)
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
                HStack {
                    TextField("Edit comment", text: $editText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                    Button("Save") { commitEdit(id: editingId) }
                    Button("Cancel") { cancelEdit() }
                        .foregroundColor(.red)
                }
            } else {
                HStack {
                    TextField("Add a comment…", text: $newText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                    Button {
                        sendComment()
                    } label: {
                        Image(systemName: "paperplane.fill").font(.title3)
                    }
                    .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
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
}

// MARK: – Single comment row
private struct CommentRow: View {
    let comment: Comment
    let isMe: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var name: String = ""
    @State private var avatar: String?

    private static var cache: [String:(String,String?)] = [:]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: avatar ?? comment.userPhotoURL ?? "")) { phase in
                if let img = phase.image { img.resizable() } else { Color.gray.opacity(0.3) }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? comment.username : name).font(.subheadline).bold()
                Text(comment.text)
            }
            Spacer(minLength: 0)
        }
        .onAppear(perform: ensureProfile)
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
}
