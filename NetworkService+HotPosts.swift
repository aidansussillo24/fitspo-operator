//
//  NetworkService+HotPosts.swift
//  FitSpo
//
//  Hot‑Posts helper: pulls today’s posts, scores them by interaction,
//  and returns them in descending “hotness” order.
//
//  Requires one composite index on posts:
//  • likes      — desc
//  • timestamp  — desc
//

import FirebaseAuth
import FirebaseFirestore

// MARK: – Public bundle type
extension NetworkService {
    struct HotPostsBundle {
        let posts:   [Post]
        let lastDoc: DocumentSnapshot?
    }
}

// MARK: – Public API
extension NetworkService {

    /// Async/await version used by HomeView & HotPostsView
    func fetchHotPostsPage(startAfter last: DocumentSnapshot?,
                           limit: Int = 100) async throws -> HotPostsBundle
    {
        try await withCheckedThrowingContinuation { cont in
            self.fetchHotPostsPage(startAfter: last,
                                   limit: limit) { result in
                cont.resume(with: result)
            }
        }
    }

    /// Closure‑based version (handy for callbacks or Combine pipelines)
    func fetchHotPostsPage(startAfter last: DocumentSnapshot?,
                           limit: Int = 100,
                           completion: @escaping (Result<HotPostsBundle, Error>) -> Void)
    {
        // Calendar‑correct start of *today* in the user’s locale.
        let todayStart = Calendar.current.startOfDay(for: Date())

        // Primary sort = likes; secondary sort = timestamp
        var q: Query = db.collection("posts")
            .order(by: "likes",     descending: true)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        if let last { q = q.start(afterDocument: last) }

        q.getDocuments { [weak self] snap, err in
            self?.mapHotSnapshot(snapshot: snap,
                                 error: err,
                                 after: todayStart,
                                 completion: completion)
        }
    }
}

// MARK: – Private helpers
private extension NetworkService {

    func mapHotSnapshot(snapshot snap: QuerySnapshot?,
                        error err: Error?,
                        after minDate: Date,
                        completion: (Result<HotPostsBundle, Error>) -> Void)
    {
        if let err { completion(.failure(err)); return }

        guard let snap else {
            completion(.failure(NSError(domain: "HotPosts",
                                        code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: "No snapshot"])))
            return
        }

        let myUID = Auth.auth().currentUser?.uid
        var ranked: [(Post, Int)] = []

        for doc in snap.documents {
            let d = doc.data()

            guard
                let uid = d["userId"]    as? String,
                let url = d["imageURL"]  as? String,
                let cap = d["caption"]   as? String,
                let ts  = d["timestamp"] as? Timestamp
            else { continue }

            let created = ts.dateValue()
            guard created >= minDate else { continue }        // today only

            // Basic interaction metrics (default to 0 if field missing)
            let likes    = d["likes"]         as? Int ?? 0
            let comments = d["commentsCount"] as? Int ?? 0
            let shares   = d["sharesCount"]   as? Int ?? 0
            let likedBy  = d["likedBy"]       as? [String] ?? []

            let post = Post(
                id:           doc.documentID,
                userId:       uid,
                imageURL:     url,
                caption:      cap,
                timestamp:    created,
                likes:        likes,
                isLiked:      myUID.map { likedBy.contains($0) } ?? false,
                latitude:     d["latitude"]     as? Double,
                longitude:    d["longitude"]    as? Double,
                temp:         d["temp"]         as? Double,
                weatherIcon:  d["weatherIcon"]  as? String,
                hashtags:     d["hashtags"]     as? [String] ?? []
            )

            // Score = likes + comments + shares
            ranked.append((post, likes + comments + shares))
        }

        // Highest score first; newest wins ties
        ranked.sort { lhs, rhs in
            lhs.1 == rhs.1
            ? lhs.0.timestamp > rhs.0.timestamp
            : lhs.1 > rhs.1
        }

        completion(.success(.init(posts: ranked.map(\.0),
                                  lastDoc: snap.documents.last)))
    }
}
