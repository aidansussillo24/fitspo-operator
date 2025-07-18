import Foundation

struct Chat: Identifiable {
    let id: String
    let participants: [String]
    let lastMessage: String
    let lastTimestamp: Date
}
