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
}
