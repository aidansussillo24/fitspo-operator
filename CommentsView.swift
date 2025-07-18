//
//  CommentsView.swift
//

import SwiftUI
import FirebaseAuth

struct CommentsView: View {
  let post: Post
  @Environment(\.dismiss) private var dismiss

  @State private var comments: [Comment] = []
  @State private var newCommentText = ""
  @FocusState private var isInputActive: Bool
  @State private var isLoading = false

  var body: some View {
    VStack(spacing: 0) {

      // ── Top bar ───────────────────────────
      HStack {
        Button("Back") { dismiss() }
        Spacer()
        Text("Comments").font(.headline)
        Spacer()
        Color.clear.frame(width: 44)           // keeps title centered
      }
      .padding()
      .background(.ultraThinMaterial)

      // ── Comment list ──────────────────────
      if isLoading {
        Spacer()
        ProgressView()
        Spacer()
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(comments) { CommentRow(comment: $0) }
          }
          .padding()
        }
      }

      // ── Input bar ─────────────────────────
      HStack {
        TextField("Add a comment…", text: $newCommentText)
          .textFieldStyle(.roundedBorder)
          .focused($isInputActive)

        Button {
          sendComment()
        } label: {
          Image(systemName: "paperplane.fill")
        }
        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .padding()
      .background(.ultraThinMaterial)
    }
    .task(loadComments)
  }

  // MARK: – Networking

  private func loadComments() {
    isLoading = true
    NetworkService.shared.fetchComments(for: post.id) { result in
      DispatchQueue.main.async {
        isLoading = false
        if case .success(let list) = result { comments = list }
      }
    }
  }

  private func sendComment() {
    let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, let user = Auth.auth().currentUser else { return }

    newCommentText = ""
    isInputActive  = false

    let comment = Comment(
      postId: post.id,
      userId: user.uid,
      username: user.displayName ?? "User",
      userPhotoURL: user.photoURL?.absoluteString,
      text: text
    )

    NetworkService.shared.addComment(to: post.id, comment: comment) { _ in
      NetworkService.shared.handleCommentNotifications(postOwnerId: post.userId, comment: comment)
      loadComments()        // simple refresh
    }
  }
}

// MARK: – One row

private struct CommentRow: View {
  let comment: Comment

  var body: some View {
    HStack(alignment: .top, spacing: 8) {

      // Avatar
      AsyncImage(url: URL(string: comment.userPhotoURL ?? "")) { phase in
        if let img = phase.image { img.resizable() }
        else { Color.gray.opacity(0.3) }
      }
      .frame(width: 32, height: 32)
      .clipShape(Circle())

      // Bubble
      VStack(alignment: .leading, spacing: 4) {
        Text(comment.username).font(.subheadline).bold()
        Text(comment.text)
      }
      Spacer(minLength: 0)
    }
  }
}
