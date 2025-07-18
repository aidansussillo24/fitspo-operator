import SwiftUI

struct OutfitCardView: View {
    let outfit: Outfit
    let isHighlighted: Bool
    let toggleLike: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = URL(string: outfit.imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    case .success(let img):
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .clipped()
                    case .failure:
                        Image(systemName: "photo.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(12)
            }

            Text(outfit.username)
                .font(.headline)

            Text(outfit.description)
                .font(.caption)
                .lineLimit(2)

            HStack {
                Text("\(outfit.likes) Likes")
                    .font(.footnote)
                Spacer()
                Image(systemName: outfit.isLiked ? "heart.fill" : "heart")
                    .foregroundColor(outfit.isLiked ? .red : .gray)
                    .onTapGesture { toggleLike() }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHighlighted ? Color.yellow.opacity(0.2) : Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture(perform: onTap)
    }
}
