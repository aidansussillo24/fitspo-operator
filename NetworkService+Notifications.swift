import Foundation
import FirebaseAuth
import FirebaseFirestore

extension NetworkService {
    // MARK: - Mention extraction
    static func extractMentions(from text: String) -> [String] {
        let pattern = "(?:\\s|^)@([A-Za-z0-9_]+)"
        guard let rx = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = rx.matches(in: text, range: nsRange)
        return Array(Set(matches.compactMap {
            Range($0.range(at: 1), in: text).map { text[$0].lowercased() }
        }))
    }

    // MARK: - Lookup UID for a username
    func lookupUserId(username: String, completion: @escaping (String?) -> Void) {
        db.collection("users")
            .whereField("username_lc", isEqualTo: username.lowercased())
            .limit(to: 1)
            .getDocuments { snap, _ in
                completion(snap?.documents.first?.documentID)
            }
    }

    // MARK: - Create notification document
    func addNotification(to userId: String,
                         notification: UserNotification,
                         completion: @escaping (Result<Void,Error>) -> Void) {
        db.collection("users")
            .document(userId)
            .collection("notifications")
            .document(notification.id)
            .setData(notification.dictionary) { err in
                if let err = err { completion(.failure(err)) }
                else             { completion(.success(())) }
            }
    }

    // MARK: - Fetch notifications
    func fetchNotifications(for userId: String,
                            completion: @escaping (Result<[UserNotification],Error>) -> Void) {
        db.collection("users")
            .document(userId)
            .collection("notifications")
            .order(by: "timestamp", descending: true)
            .getDocuments { snap, err in
                if let err = err { completion(.failure(err)); return }
                let list = snap?.documents.compactMap { UserNotification(from: $0.data()) } ?? []
                completion(.success(list))
            }
    }

    // MARK: - Observe notifications
    @discardableResult
    func observeNotifications(for userId: String,
                              onChange: @escaping ([UserNotification]) -> Void) -> ListenerRegistration {
        db.collection("users")
            .document(userId)
            .collection("notifications")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snap, _ in
                let list = snap?.documents.compactMap { UserNotification(from: $0.data()) } ?? []
                onChange(list)
            }
    }

    // MARK: - Convenience: create notifications for a new comment
    func handleCommentNotifications(postOwnerId: String, comment: Comment) {
        // Notify post owner if someone else commented
        if postOwnerId != comment.userId {
            let note = UserNotification(postId: comment.postId,
                                       fromUserId: comment.userId,
                                       fromUsername: comment.username,
                                       fromAvatarURL: comment.userPhotoURL,
                                       text: comment.text,
                                       kind: .comment)
            addNotification(to: postOwnerId, notification: note) { _ in }
        }

        // Notify any mentioned users
        let mentions = Self.extractMentions(from: comment.text)
        for name in mentions {
            lookupUserId(username: name) { uid in
                guard let uid, uid != comment.userId, uid != postOwnerId else { return }
                let note = UserNotification(postId: comment.postId,
                                           fromUserId: comment.userId,
                                           fromUsername: comment.username,
                                           fromAvatarURL: comment.userPhotoURL,
                                           text: comment.text,
                                           kind: .mention)
                self.addNotification(to: uid, notification: note) { _ in }
            }
        }
    }

    // MARK: - Convenience: create notification for a like
    func handleLikeNotification(postOwnerId: String,
                                postId: String,
                                fromUserId: String) {
        guard postOwnerId != fromUserId else { return }

        db.collection("users").document(fromUserId).getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let name   = data["displayName"] as? String ??
                         Auth.auth().currentUser?.displayName ?? "User"
            let avatar = data["avatarURL"] as? String ??
                         Auth.auth().currentUser?.photoURL?.absoluteString

            let note = UserNotification(postId: postId,
                                       fromUserId: fromUserId,
                                       fromUsername: name,
                                       fromAvatarURL: avatar,
                                       text: "",
                                       kind: .like)
            self.addNotification(to: postOwnerId, notification: note) { _ in }
        }
    }

    // MARK: - Convenience: create notifications for user tags
    func handleTagNotifications(postId: String,
                                caption: String,
                                fromUserId: String,
                                taggedUsers: [UserTag]) {
        let targets = taggedUsers.map { $0.id }.filter { $0 != fromUserId }
        guard !targets.isEmpty else { return }

        db.collection("users").document(fromUserId).getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let name   = data["displayName"] as? String ??
                         Auth.auth().currentUser?.displayName ?? "User"
            let avatar = data["avatarURL"] as? String ??
                         Auth.auth().currentUser?.photoURL?.absoluteString

            for uid in targets {
                let note = UserNotification(postId: postId,
                                           fromUserId: fromUserId,
                                           fromUsername: name,
                                           fromAvatarURL: avatar,
                                           text: caption,
                                           kind: .tag)
                self.addNotification(to: uid, notification: note) { _ in }
            }
        }
    }

    // MARK: - Remove notifications for a deleted post
    /// Delete any notifications that reference the given post ID.
    func deleteNotifications(forPostId postId: String,
                             completion: ((Error?) -> Void)? = nil) {
        db.collectionGroup("notifications")
            .whereField("postId", isEqualTo: postId)
            .getDocuments { snap, err in
                if let err = err { completion?(err); return }
                let batch = self.db.batch()
                snap?.documents.forEach { batch.deleteDocument($0.reference) }
                batch.commit { batchErr in completion?(batchErr) }
            }
    }

    // MARK: - Remove a single notification
    /// Delete the specified notification for the given user.
    func deleteNotification(userId: String,
                            notificationId: String,
                            completion: ((Error?) -> Void)? = nil) {
        db.collection("users")
            .document(userId)
            .collection("notifications")
            .document(notificationId)
            .delete { err in completion?(err) }
    }
}
