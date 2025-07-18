//
//  NetworkService+FetchPost.swift
//  FitSpo
//

import FirebaseAuth
import FirebaseFirestore

extension NetworkService {

    /// Fetch a single post document by ID
    func fetchPost(
        id: String,
        completion: @escaping (Result<Post, Error>) -> Void
    ) {
        db.collection("posts").document(id).getDocument { snap, err in
            if let err { completion(.failure(err)); return }
            guard let snap, let d = snap.data() else {
                return completion(.failure(NSError(
                    domain: "FetchPost",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Document not found"])))
            }

            guard
                let uid   = d["userId"]    as? String,
                let url   = d["imageURL"]  as? String,
                let cap   = d["caption"]   as? String,
                let ts    = d["timestamp"] as? Timestamp,
                let likes = d["likes"]     as? Int
            else {
                return completion(.failure(NSError(
                    domain: "FetchPost",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Malformed post data"])))
            }

            let me      = Auth.auth().currentUser?.uid
            let likedBy = d["likedBy"] as? [String] ?? []

            let post = Post(
                id:        snap.documentID,
                userId:    uid,
                imageURL:  url,
                caption:   cap,
                timestamp: ts.dateValue(),
                likes:     likes,
                isLiked:   me.map { likedBy.contains($0) } ?? false,
                latitude:  d["latitude"]  as? Double,
                longitude: d["longitude"] as? Double,
                temp:      d["temp"]      as? Double,
                weatherIcon: d["weatherIcon"] as? String,
                hashtags:  d["hashtags"]  as? [String] ?? []     // ← NEW
            )

            completion(.success(post))
        }
    }
}
