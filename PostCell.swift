// PostCell.swift
import SwiftUI

/// A reusable square‐thumbnail cell for any post.
struct PostCell: View, Identifiable {
    let post: Post
    var id: String { post.id }

    var body: some View {
        AsyncImage(url: URL(string: post.imageURL)) { phase in
            switch phase {
            case .empty:
                Color.gray
                    .opacity(0.2)
                    .aspectRatio(1, contentMode: .fit)

            case .success(let img):
                img
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()

            case .failure:
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .foregroundColor(.secondary)

            @unknown default:
                EmptyView()
            }
        }
        .cornerRadius(8)
    }
}
