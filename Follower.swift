import Foundation

struct Follower: Identifiable {
    let id: Int
    let username: String
    let profileImageName: String
    
    static let sampleFollowers: [Follower] = [
        Follower(id: 1, username: "StyleGuru", profileImageName: "profile"),
        Follower(id: 2, username: "AthleticChic", profileImageName: "profile"),
        Follower(id: 3, username: "TrendyTeen", profileImageName: "profile"),
    ]
    
    static let sampleFollowing: [Follower] = [
        Follower(id: 4, username: "Fashionista01", profileImageName: "profile"),
        Follower(id: 5, username: "CoolDresser", profileImageName: "profile"),
    ]
}
