import Foundation

/// A single “outfit” in your explore/follow feeds.
struct Outfit: Identifiable, Codable {
    let id: String
    let username: String
    let imageURL: String
    let description: String

    // now mutable so we can update likes & isLiked
    var likes: Int
    var isLiked: Bool

    enum CodingKeys: String, CodingKey {
        case id, username, imageURL, description, likes, isLiked
    }
}
