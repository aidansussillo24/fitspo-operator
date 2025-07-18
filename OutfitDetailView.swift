// OutfitDetailView.swift
import SwiftUI
import FirebaseFirestore

struct OutfitDetailView: View {
    let outfit: Outfit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Big header image
                if let url = URL(string: outfit.imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: 300)
                        case .success(let img):
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: 300)
                                .clipped()
                        case .failure:
                            Image(systemName: "photo.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 300)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                // Textual details
                Group {
                    Text(outfit.username)
                        .font(.title)
                        .padding(.top, 8)
                    Text(outfit.description)
                        .font(.body)
                        .padding(.vertical, 4)
                    HStack {
                        Text("\(outfit.likes) Likes")
                        Spacer()
                        Image(systemName: outfit.isLiked ? "heart.fill" : "heart")
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Outfit Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OutfitDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OutfitDetailView(
                outfit: Outfit(
                    id: "1",
                    username: "SampleUser",
                    imageURL: "https://placekitten.com/600/300",
                    description: "This is a more detailed view of the outfit—showing how it all comes together!",
                    likes: 123,
                    isLiked: true
                )
            )
        }
    }
}
