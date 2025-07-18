//
//  NetworkService+Explore.swift
//  FitSpo
//

import FirebaseAuth
import FirebaseFirestore

extension NetworkService {
    
    // Bundle returned to ExploreView for paging
    struct TrendingBundle {
        let posts:   [Post]
        let lastDoc: DocumentSnapshot?
    }
    
    // MARK: – async / await API
    func fetchTrendingPosts(
        startAfter last: DocumentSnapshot?
    ) async throws -> TrendingBundle {
        try await withCheckedThrowingContinuation { cont in
            fetchTrendingPosts(startAfter: last) { cont.resume(with: $0) }
        }
    }
    //Edited this out and it fixed our hotposts issue
    //func fetchHotPosts(limit: Int = 10) async throws -> [Post] {
    //try await withCheckedThrowingContinuation { cont in
    //fetchHotPosts(limit: limit) { cont.resume(with: $0) }
    //}
    //}
    
    //func fetchHotPostsPage(
    //startAfter last: DocumentSnapshot?,
    //limit: Int = 20
    //) async throws -> TrendingBundle {
    //try await withCheckedThrowingContinuation { cont in
    //fetchHotPostsPage(startAfter: last, limit: limit) { cont.resume(with: $0) }
    //}
    //}
    
    // MARK: – closure API
    func fetchTrendingPosts(
        startAfter last: DocumentSnapshot?,
        completion: @escaping (Result<TrendingBundle,Error>) -> Void
    ) {
        //-------------------------------------------------------------
        // Choose ordering based on whether the paging cursor has “likes”
        //-------------------------------------------------------------
        let needsFallback = (last?.data()?["likes"] == nil)
        
        var q: Query = db.collection("posts")
        
        if needsFallback {
            q = q.order(by: "timestamp", descending: true)
        } else {
            q = q.order(by: "likes",     descending: true)
                .order(by: "timestamp", descending: true)
        }
        
        q = q.limit(to: 20)
        if let last { q = q.start(afterDocument: last) }
        
        q.getDocuments { [weak self] snap, err in
            self?.mapSnapshot(snapshot: snap,
                              error:     err,
                              completion: completion)
        }
    }
    
    // MARK: – Snapshot → Post array
    private func mapSnapshot(
        snapshot snap: QuerySnapshot?,
        error err: Error?,
        completion: (Result<TrendingBundle,Error>) -> Void
    ) {
        if let err { completion(.failure(err)); return }
        guard let snap else {
            completion(.failure(NSError(
                domain: "Explore",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No snapshot"])))
            return
        }
        
        let me = Auth.auth().currentUser?.uid
        let posts: [Post] = snap.documents.compactMap { doc in
            let d = doc.data()
            guard
                let uid   = d["userId"]    as? String,
                let url   = d["imageURL"]  as? String,
                let cap   = d["caption"]   as? String,
                let ts    = d["timestamp"] as? Timestamp,
                let likes = d["likes"]     as? Int?
            else { return nil }
            
            let likedBy = d["likedBy"] as? [String] ?? []
            
            return Post(
                id:        doc.documentID,
                userId:    uid,
                imageURL:  url,
                caption:   cap,
                timestamp: ts.dateValue(),
                likes:     likes ?? 0,
                isLiked:   me.map { likedBy.contains($0) } ?? false,
                latitude:  d["latitude"]  as? Double,
                longitude: d["longitude"] as? Double,
                temp:      d["temp"]      as? Double,
                weatherIcon: d["weatherIcon"] as? String,
                hashtags:  d["hashtags"]  as? [String] ?? []
            )
        }
        
        completion(.success(.init(posts: posts,
                                  lastDoc: snap.documents.last)))
    }
}
    // MARK: - Hot Posts
    //func fetchHotPosts(limit: Int = 10,
      //                 completion: @escaping (Result<[Post],Error>) -> Void) {
        //let since = Date().addingTimeInterval(-12 * 60 * 60)
        //let t = Timestamp(date: since)
        //db.collection("posts")
          //  .whereField("timestamp", isGreaterThan: t)
            //.order(by: "likes", descending: true)
            //.order(by: "timestamp", descending: true)
            //.limit(to: limit * 2)
            //.getDocuments { [weak self] snap, err in
              //  self?.mapSnapshot(snapshot: snap, error: err) { result in
                //    switch result {
                  //  case .success(let bundle):
                    //    var unique: [Post] = []
                      //  var seen: Set<String> = []
                        //for p in bundle.posts {
                            //if !seen.contains(p.userId) {
                               // unique.append(p)
                               // seen.insert(p.userId)
                            //}
                            //if unique.count >= limit { break }
                        //}
                        //completion(.success(unique))
                    //case .failure(let e): completion(.failure(e))
                    //}
                //}
            //}
    //}

  //  func fetchHotPostsPage(
    //    startAfter last: DocumentSnapshot?,
      //  limit: Int = 20,
        //completion: @escaping (Result<TrendingBundle,Error>) -> Void
    //) {
      //  let since = Date().addingTimeInterval(-12 * 60 * 60)
        //let t = Timestamp(date: since)

//        let needsFallback = (last?.data()?["likes"] == nil)
//
  //      var q: Query = db.collection("posts")
    //        .whereField("timestamp", isGreaterThan: t)

      //  if needsFallback {
        //    q = q.order(by: "timestamp", descending: true)
        //} else {
            //q = q.order(by: "likes", descending: true)
          //       .order(by: "timestamp", descending: true)
        //}

        //q = q.limit(to: limit)
        //if let last { q = q.start(afterDocument: last) }

        //q.getDocuments { [weak self] snap, err in
          //  self?.mapSnapshot(snapshot: snap, error: err) { result in
              //  switch result {
            //    case .success(let bundle):
                  //  var unique: [Post] = []
                //    var seen: Set<String> = []
                   // for p in bundle.posts {
                     //   if !seen.contains(p.userId) {
                       //     unique.append(p)
                         //   seen.insert(p.userId)
                        //}
                    //}
                    //completion(.success(.init(posts: unique,
                  //                            lastDoc: bundle.lastDoc)))
                //case .failure(let err): completion(.failure(err))
                //}
            //}
        //}
    //}
//}
