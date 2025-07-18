//
//  PostCardView.swift
//  FitSpo
//
//  Feed card now uses RemoteImage with automatic retry & caching.
//

import SwiftUI
import FirebaseFirestore

struct PostCardView: View {
    let post: Post
    let onLike: () -> Void

    @State private var authorName      = ""
    @State private var authorAvatarURL = ""
    @State private var isLoadingAuthor = true
    @State private var showHeart       = false

    @Environment(\.openURL) private var openURL

    private var forecastURL: URL? {
        guard let lat = post.latitude,
              let lon = post.longitude
        else { return nil }
        let urlString = "https://weather.com/weather/today/l/\(lat),\(lon)"
        return URL(string: urlString)
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Tap image → PostDetail ─────────────────────────────
            NavigationLink(destination: PostDetailView(post: post)) {
                RemoteImage(url: post.imageURL, contentMode: .fill)
                    .aspectRatio(4/5, contentMode: .fill)
                    .clipped()
                    .highPriorityGesture(
                        TapGesture(count: 2).onEnded { handleDoubleTapLike() }
                    )
                    .overlay(HeartBurstView(trigger: $showHeart))
            }
            .buttonStyle(.plain)

            // ── Footer (avatar, name, like button) ─────────────────
            HStack(spacing: 8) {

                NavigationLink(destination: ProfileView(userId: post.userId)) {
                    HStack(spacing: 8) {
                        avatarThumb
                        Text(isLoadingAuthor ? "Loading…" : authorName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                            .layoutPriority(1)

                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onLike) {
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        Text("\(post.likes)")
                    }
                    .frame(width: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(Color.white)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1),
                radius: 1, x: 0, y: 1)
        .overlay(alignment: .topTrailing) { weatherIconView }
        .onAppear(perform: fetchAuthor)
    }

    // MARK: – avatar helper
    @ViewBuilder private var avatarThumb: some View {
        if let url = URL(string: authorAvatarURL),
           !authorAvatarURL.isEmpty {
            RemoteImage(url: url.absoluteString, contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.gray)
        }
    }

    // MARK: – weather helper
    @ViewBuilder private var weatherIconView: some View {
        if let name = post.weatherSymbolName {
            HStack(spacing: 4) {
                if let temp = post.tempString {
                    Text(temp)
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                if let (primary, secondary) = post.weatherIconColors {
                    if let secondary = secondary {
                        Image(systemName: name)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(primary, secondary)
                    } else {
                        Image(systemName: name)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(primary)
                    }
                } else {
                    Image(systemName: name)
                }
            }
            .padding(6)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
            .padding(8)
            .onTapGesture { if let url = forecastURL { openURL(url) } }
        }
    }

    // MARK: – Author fetch
    private func fetchAuthor() {
        Firestore.firestore()
            .collection("users")
            .document(post.userId)
            .getDocument { snap, err in
                isLoadingAuthor = false
                guard err == nil, let d = snap?.data() else {
                    authorName = "Unknown"; return
                }
                authorName      = d["displayName"] as? String ?? "Unknown"
                authorAvatarURL = d["avatarURL"]   as? String ?? ""
            }
    }

    private func handleDoubleTapLike() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        showHeart = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showHeart = false }
        if !post.isLiked { onLike() }
    }
}

#if DEBUG
struct PostCardView_Previews: PreviewProvider {
    static var previews: some View {
        PostCardView(
            post: Post(
                id:        "1",
                userId:    "alice",
                imageURL:  "https://via.placeholder.com/400x600",
                caption:   "Preview card",
                timestamp: Date(),
                likes:     42,
                isLiked:   false,
                latitude:  nil,
                longitude: nil,
                temp:      22,
                weatherIcon: "01d",
                hashtags:  []
            )
        ) { }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
