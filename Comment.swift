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
    let likeCount: Int
    let likedBy: [String] // Array of userIds who liked this comment

    // Convenience dictionary for Firestore writes
    var dictionary: [String: Any] {
        [
            "id":            id,
            "postId":        postId,
            "userId":        userId,
            "username":      username,
            "userPhotoURL":  userPhotoURL as Any,
            "text":          text,
            "timestamp":     timestamp.timeIntervalSince1970,
            "likeCount":     likeCount,
            "likedBy":       likedBy
        ]
    }

    init(id: String = UUID().uuidString,
         postId: String,
         userId: String,
         username: String,
         userPhotoURL: String?,
         text: String,
         timestamp: Date = .init(),
         likeCount: Int = 0,
         likedBy: [String] = []) {
        self.id           = id
        self.postId       = postId
        self.userId       = userId
        self.username     = username
        self.userPhotoURL = userPhotoURL
        self.text         = text
        self.timestamp    = timestamp
        self.likeCount    = likeCount
        self.likedBy      = likedBy
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
        self.likeCount    = dict["likeCount"] as? Int ?? 0
        self.likedBy      = dict["likedBy"] as? [String] ?? []
    }
    
    /// Instagram-style time formatting (e.g., "1d", "2h", "3m", "now")
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(timestamp)
        
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        let weeks = Int(interval / 604800)
        
        if weeks > 0 {
            return "\(weeks)w"
        } else if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
}
