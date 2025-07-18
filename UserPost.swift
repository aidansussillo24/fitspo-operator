import Foundation

struct UserPost: Identifiable {
    let id: Int
    let imageName: String
    let description: String
    let likes: Int
    
    static let samplePosts: [UserPost] = [
        UserPost(id: 1, imageName: "outfit1", description: "A trendy summer look.", likes: 120),
        UserPost(id: 2, imageName: "outfit2", description: "Casual chic for any occasion.", likes: 90),
        UserPost(id: 3, imageName: "outfit3", description: "Perfect autumn style.", likes: 140),
        UserPost(id: 4, imageName: "outfit4", description: "Winter vibes.", likes: 85)
    ]
}
