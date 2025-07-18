import SwiftUI
import FirebaseFirestore

/// Displays the daily top posts in a simple vertical feed.
/// Swiping through shows each post with the regular detail layout.
struct HotPostsView: View {

    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var lastDoc: DocumentSnapshot? = nil
    @State private var reachedEnd = false
    @State private var lastPrefetchIndex = -1

    private let PAGE_SIZE = 10
    private let PREFETCH_AHEAD = 4

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { idx, post in
                    PostDetailView(post: post, rank: idx + 1, navTitle: "🔥 Hot Today")
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                        .padding(.horizontal)
                        .onAppear { maybePrefetch(after: post) }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Hot Today")
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(.red)
                    Text("Hot Today")
                }
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let bundle = try await NetworkService.shared
                .fetchHotPostsPage(startAfter: nil, limit: PAGE_SIZE)
            posts = bundle.posts
            lastDoc = bundle.lastDoc
            reachedEnd = bundle.lastDoc == nil
            lastPrefetchIndex = -1
        } catch {
            print("HotPosts fetch error:", error.localizedDescription)
        }
    }

    private func loadNextPage() {
        guard !isLoading, !reachedEnd else { return }
        isLoading = true
        NetworkService.shared.fetchHotPostsPage(startAfter: lastDoc,
                                               limit: PAGE_SIZE) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let bundle):
                    let newOnes = bundle.posts.filter { p in
                        !posts.contains(where: { $0.id == p.id })
                    }
                    posts.append(contentsOf: newOnes)
                    lastDoc = bundle.lastDoc
                    reachedEnd = bundle.lastDoc == nil
                case .failure(let err):
                    print("Hot posts page error:", err)
                }
            }
        }
    }

    private func maybePrefetch(after post: Post) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let remaining = posts.count - idx - 1
        guard remaining <= PREFETCH_AHEAD else { return }

        guard idx != lastPrefetchIndex else { return }
        lastPrefetchIndex = idx
        loadNextPage()
    }
}
