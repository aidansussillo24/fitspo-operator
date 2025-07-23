//
//  NetworkService+HashtagSearch.swift
//  FitSpo
//
//  Simple Firestore hashtag search used as a fallback when Algolia is
//  unavailable.
//
import FirebaseFirestore

extension NetworkService {
    /// Returns up to `limit` posts whose `hashtags` array contains the given tag.
    /// Results are sorted by like count on the client to avoid requiring a
    /// Firestore composite index.
    func searchPosts(hashtag raw: String, limit: Int = 40) async throws -> [Post] {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tag.isEmpty else { return [] }

        let snap = try await db.collection("posts")
            .whereField("hashtags", arrayContains: tag)
            .limit(to: limit)
            .getDocuments()

        var posts = snap.documents.compactMap { Self.decodePost(doc: $0) }
        posts.sort { $0.likes > $1.likes }
        return posts
    }

    /// Fetches a set of popular hashtags by scanning recent posts.
    /// - Parameters:
    ///   - limit: Maximum number of tags to return.
    ///   - maxPosts: Maximum number of posts to scan.
    /// - Returns: Up to `limit` hashtag strings sorted by usage count.
    func fetchTopHashtags(limit: Int = 20, maxPosts: Int = 200) async throws -> [String] {
        var counts: [String:Int] = [:]
        var last: DocumentSnapshot?
        var scanned = 0

        while scanned < maxPosts {
            let bundle = try await fetchPostsPageAsync(startAfter: last, limit: 50)
            for post in bundle.posts {
                for tag in post.hashtags { counts[tag, default: 0] += 1 }
            }
            scanned += bundle.posts.count
            last = bundle.lastDoc
            if bundle.posts.isEmpty || last == nil { break }
        }

        let sorted = counts.sorted { $0.value > $1.value }.map { $0.key }
        return Array(sorted.prefix(limit))
    }

    /// Suggests hashtags that start with the given prefix.
    /// Results are ordered by popularity within the scanned posts.
    func suggestHashtags(prefix raw: String,
                         limit: Int = 10,
                         maxPosts: Int = 200) async throws -> [String] {
        let p = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !p.isEmpty else { return [] }

        let all = try await fetchTopHashtags(limit: .max, maxPosts: maxPosts)
        return all.filter { $0.hasPrefix(p) }.prefix(limit).map { $0 }
    }

    // MARK: - Internal helpers

    private func fetchPostsPageAsync(startAfter last: DocumentSnapshot?,
                                     limit: Int) async throws -> TrendingBundle {
        try await withCheckedThrowingContinuation { cont in
            fetchPostsPage(pageSize: limit, after: last) { result in
                cont.resume(with: result.map { TrendingBundle(posts: $0.0,
                                                             lastDoc: $0.1) })
            }
        }
    }
}
