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

    /// Fetches a set of trending hashtags based on recent popular posts.
    /// - Parameters:
    ///   - limit: Maximum number of tags to return.
    ///   - pages: Number of pages of trending posts to scan.
    /// - Returns: Up to `limit` hashtag strings sorted by popularity.
    func fetchTopHashtags(limit: Int = 20, pages: Int = 3) async throws -> [String] {
        var counts: [String:Int] = [:]
        var last: DocumentSnapshot?
        var scanned = 0

        while scanned < pages {
            let bundle = try await fetchTrendingPosts(startAfter: last)
            for post in bundle.posts {
                for tag in post.hashtags { counts[tag, default: 0] += 1 }
            }
            last = bundle.lastDoc
            if last == nil { break }
            scanned += 1
        }

        let sorted = counts.sorted { $0.value > $1.value }.map { $0.key }
        return Array(sorted.prefix(limit))
    }
}
