import Foundation

/// A single user comment attached to a post.
struct Comment: Identifiable, Codable {
    let id: String
    let postId: String
    let userId: String
    let username: String
    let userPhotoURL: String?
    let text: String
    let timestamp: Date

    // Convenience dictionary for Firestore writes
    var dictionary: [String: Any] {
        [
            "id":            id,
            "postId":        postId,
            "userId":        userId,
            "username":      username,
            "userPhotoURL":  userPhotoURL as Any,
            "text":          text,
            "timestamp":     timestamp.timeIntervalSince1970
        ]
    }

    init(id: String = UUID().uuidString,
         postId: String,
         userId: String,
         username: String,
         userPhotoURL: String?,
         text: String,
         timestamp: Date = .init()) {
        self.id           = id
        self.postId       = postId
        self.userId       = userId
        self.username     = username
        self.userPhotoURL = userPhotoURL
        self.text         = text
        self.timestamp    = timestamp
    }

    /// Build from Firestore data
    init?(from dict: [String: Any]) {
        guard
            let id        = dict["id"]        as? String,
            let postId    = dict["postId"]    as? String,
            let userId    = dict["userId"]    as? String,
            let username  = dict["username"]  as? String,
            let text      = dict["text"]      as? String,
            let ts        = dict["timestamp"] as? TimeInterval
        else { return nil }

        self.id           = id
        self.postId       = postId
        self.userId       = userId
        self.username     = username
        self.userPhotoURL = dict["userPhotoURL"] as? String
        self.text         = text
        self.timestamp    = Date(timeIntervalSince1970: ts)
    }
}
