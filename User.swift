import Foundation

struct User: Identifiable, Codable {
    let id: String
    let displayName: String
    let avatarURL: String?
}
