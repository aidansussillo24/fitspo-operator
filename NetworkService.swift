//
//  NetworkService.swift
//  FitSpo
//
//  Core networking layer + Firestore helpers.
//  Updated 2025‑06‑24:
//  • Removed duplicate fetchComments(…) – comment helpers stay
//    in NetworkService+Comments.swift.
//  • Comment.fromFirestore shim still present (no FirebaseFirestoreSwift).
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Network
import UIKit

// ─────────────────────────────────────────────────────────────
final class NetworkService {

    // MARK: – singleton & reachability
    static let shared = NetworkService()
    private init() { startPathMonitor() }

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "FitSpo.NetMonitor")
    private var pathStatus: NWPath.Status = .satisfied
    static var isOnline: Bool { shared.pathStatus == .satisfied }

    /// OpenWeather API key – replace with your own

    private static let openWeatherKey = "fa990912bd254666ff34a71ae54781ba"


    private func startPathMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.pathStatus = path.status
        }
        monitor.start(queue: queue)
    }

    // MARK: – Firebase handles
    let db      = Firestore.firestore()
    private let storage = Storage.storage().reference()

    // ====================================================================
    // MARK: USER PROFILE
    // ====================================================================
    func createUserProfile(userId: String,
                           data: [String:Any]) async throws {
        var d = data
        if let username = data["username"]    as? String { d["username_lc"]    = username.lowercased() }
        if let display  = data["displayName"] as? String { d["displayName_lc"] = display.lowercased() }
        try await db.collection("users").document(userId).setData(d)
    }

    // ====================================================================
    // MARK: OUTFIT helpers
    // ====================================================================
    static func parseOutfitItems(_ raw: Any?) -> [OutfitItem] {
        guard let arr = raw as? [[String:Any]] else { return [] }
        return arr.compactMap { dict in
            guard
                let label = dict["label"]   as? String,
                let url   = dict["shopURL"] as? String
            else { return nil }
            let brand = dict["brand"] as? String ?? ""
            let id    = dict["id"]    as? String ?? UUID().uuidString
            return OutfitItem(id: id, label: label, brand: brand, shopURL: url)
        }
    }

    static func parseOutfitTags(_ raw: Any?) -> [OutfitTag] {
        guard let arr = raw as? [[String:Any]] else { return [] }
        return arr.compactMap { dict in
            guard
                let itemId = dict["itemId"] as? String,
                let x      = dict["xNorm"]  as? Double,
                let y      = dict["yNorm"]  as? Double
            else { return nil }
            let id = dict["id"] as? String ?? UUID().uuidString
            return OutfitTag(id: id, itemId: itemId, xNorm: x, yNorm: y)
        }
    }

    // ====================================================================
    // MARK: UPLOAD POST (manual items + pins)
    // ====================================================================
    func uploadPost(
        image: UIImage,
        caption: String,
        latitude: Double?,
        longitude: Double?,
        tags: [UserTag],
        outfitItems: [OutfitItem],
        outfitTags: [OutfitTag],
        completion: @escaping (Result<Void,Error>) -> Void
    ) {
        guard let me = Auth.auth().currentUser else {
            return completion(.failure(Self.authError()))
        }
        guard let jpg = image.jpegData(compressionQuality: 0.8) else {
            return completion(.failure(Self.imageError()))
        }

        // 1️⃣ upload JPEG
        let imgID = UUID().uuidString
        let ref   = storage.child("post_images/\(imgID).jpg")
        ref.putData(jpg, metadata: nil) { [weak self] _, err in
            if let err { completion(.failure(err)); return }

            ref.downloadURL { url, err in
                if let err { completion(.failure(err)); return }
                guard let self, let url else {
                    return completion(.failure(Self.storageURLError()))
                }

                // 2️⃣ payload
                var data: [String:Any] = [
                    "userId"      : me.uid,
                    "imageURL"    : url.absoluteString,
                    "caption"     : caption,
                    "timestamp"   : Timestamp(date: Date()),
                    "likes"       : 0,
                    "isLiked"     : false,
                    "likedBy"     : [],
                    "hashtags"    : Self.extractHashtags(from: caption),
                    "scanResults" : outfitItems.map { [
                        "id"     : $0.id,
                        "label"  : $0.label,
                        "brand"  : $0.brand,
                        "shopURL": $0.shopURL
                    ]},
                    "outfitTags"  : outfitTags.map { [
                        "id"    : $0.id,
                        "itemId": $0.itemId,
                        "xNorm" : $0.xNorm,
                        "yNorm" : $0.yNorm
                    ]}
                ]
                if let latitude  { data["latitude"]  = latitude  }
                if let longitude { data["longitude"] = longitude }
                
                func finishWrite() {
                    // 3️⃣ write doc
                    let doc = self.db.collection("posts").document()
                    doc.setData(data) { err in
                        if let err { completion(.failure(err)); return }

                        // 4️⃣ face‑tags sub‑docs
                        guard !tags.isEmpty else {
                            NotificationCenter.default.post(name: .didUploadPost, object: nil)
                            completion(.success(())); return
                        }
                        let batch = self.db.batch()
                        tags.forEach { t in
                            batch.setData([
                                "uid"        : t.id,
                                "displayName": t.displayName,
                                "xNorm"      : t.xNorm,
                                "yNorm"      : t.yNorm
                            ], forDocument: doc.collection("tags").document(t.id))
                        }
                        batch.commit { err in
                            NotificationCenter.default.post(name: .didUploadPost, object: nil)
                            if err == nil {
                                self.handleTagNotifications(postId: doc.documentID,
                                                           caption: caption,
                                                           fromUserId: me.uid,
                                                           taggedUsers: tags)
                                completion(.success(()))
                            } else {
                                completion(.failure(err!))
                            }
                        }
                    }
                }

                if let lat = latitude, let lon = longitude {
                    self.fetchWeather(lat: lat, lon: lon) { icon, temperature in
                        if let icon { data["weatherIcon"] = icon }
                        if let temperature { data["temp"] = temperature }
                        finishWrite()
                    }
                } else {
                    finishWrite()
                }
            }
        }
    }

    // ====================================================================
    // MARK: PAGED FETCH POSTS
    // ====================================================================
    func fetchPostsPage(
        pageSize: Int = 15,
        after cursor: DocumentSnapshot?,
        completion: @escaping (Result<([Post], DocumentSnapshot?),Error>) -> Void
    ) {
        var q = db.collection("posts")
                  .order(by: "timestamp", descending: true)
                  .limit(to: pageSize)
        if let cursor { q = q.start(afterDocument: cursor) }

        q.getDocuments { snap, err in
            if let err { completion(.failure(err)); return }
            let docs  = snap?.documents ?? []
            let posts = docs.compactMap(Self.decodePost)
            completion(.success((posts, docs.last)))
        }
    }

    // full dump – still used elsewhere
    func fetchPosts(completion: @escaping (Result<[Post],Error>) -> Void) {
        fetchPostsPage(pageSize: 500, after: nil) { res in
            switch res {
            case .success(let tuple): completion(.success(tuple.0))
            case .failure(let err):   completion(.failure(err))
            }
        }
    }

    // ====================================================================
    // MARK: TAGS helpers
    // ====================================================================
    func fetchTags(for postId: String,
                   completion: @escaping (Result<[UserTag],Error>) -> Void) {
        db.collection("posts").document(postId)
            .collection("tags")
            .getDocuments { snap, err in
                if let err { completion(.failure(err)); return }
                let list: [UserTag] = snap?.documents.compactMap { d in
                    guard
                        let x = d["xNorm"]       as? Double,
                        let y = d["yNorm"]       as? Double,
                        let n = d["displayName"] as? String
                    else { return nil }
                    return UserTag(id: d.documentID, xNorm: x, yNorm: y, displayName: n)
                } ?? []
                completion(.success(list))
            }
    }

    // ====================================================================
    // MARK: LIKES, DELETE, FOLLOW  (unchanged)
    // ====================================================================
    func toggleLike(post: Post,
                    completion: @escaping (Result<Post,Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(
                domain: "ToggleLike",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No current user"])))
            return
        }

        let ref       = db.collection("posts").document(post.id)
        let shouldLike = !post.isLiked
        let delta      = shouldLike ? 1 : -1
        let newLikes   = post.likes + delta

        var updates: [String: Any] = ["likes": newLikes, "isLiked": shouldLike]
        if shouldLike {
            updates["likedBy"] = FieldValue.arrayUnion([uid])
        } else {
            updates["likedBy"] = FieldValue.arrayRemove([uid])
        }

        ref.updateData(updates) { err in
            if let err { completion(.failure(err)); return }
            var updated = post
            updated.likes   = newLikes
            updated.isLiked = shouldLike
            if shouldLike {
                self.handleLikeNotification(postOwnerId: post.userId,
                                           postId: post.id,
                                           fromUserId: uid)
            }
            completion(.success(updated))
        }
    }

    func deletePost(id: String,
                    completion: @escaping (Result<Void,Error>) -> Void) {
        let ref = db.collection("posts").document(id)
        ref.getDocument { snap, err in
            if let err { completion(.failure(err)); return }

            if let urlStr = snap?.data()?["imageURL"] as? String,
               let url    = URL(string: urlStr) {
                Storage.storage()
                    .reference(withPath: url.path.dropFirst().description)
                    .delete { _ in }
            }
            ref.delete { err in
                if let err { completion(.failure(err)); return }
                self.deleteNotifications(forPostId: id) { _ in }
                completion(.success(()))
            }
        }
    }

    // Follow helpers ------------------------------------------------------
        func follow(userId: String, completion: @escaping (Error?) -> Void) {
            guard let me = Auth.auth().currentUser?.uid else {
                return completion(Self.authError())
            }
            let b = db.batch()
            b.setData([:], forDocument: db.collection("users").document(userId)
                                     .collection("followers").document(me))
            b.setData([:], forDocument: db.collection("users").document(me)
                                     .collection("following").document(userId))
            b.commit(completion: completion)
        }

        func unfollow(userId: String, completion: @escaping (Error?) -> Void) {
            guard let me = Auth.auth().currentUser?.uid else {
                return completion(Self.authError())
            }
            let b = db.batch()
            b.deleteDocument(db.collection("users").document(userId)
                               .collection("followers").document(me))
            b.deleteDocument(db.collection("users").document(me)
                               .collection("following").document(userId))
            b.commit(completion: completion)
        }

        func isFollowing(userId: String,
                         completion: @escaping (Result<Bool,Error>) -> Void) {
            guard let me = Auth.auth().currentUser?.uid else {
                return completion(.failure(Self.authError()))
            }
            db.collection("users").document(userId)
                .collection("followers").document(me)
                .getDocument { snap, err in
                    if let err { completion(.failure(err)); return }
                    completion(.success(snap?.exists == true))
                }
        }

        func fetchFollowCount(userId: String,
                              type: String,
                              completion: @escaping (Result<Int,Error>) -> Void) {
            db.collection("users").document(userId)
                .collection(type)
                .getDocuments { snap, err in
                    if let err { completion(.failure(err)); return }
                    completion(.success(snap?.documents.count ?? 0))
                }
        }
    private static func extractHashtags(from caption: String) -> [String] {
        let pattern = "(?:\\s|^)#(\\w+)"
        guard let rx = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange  = NSRange(caption.startIndex..., in: caption)
        let matches  = rx.matches(in: caption, range: nsRange)
        return Array(Set(matches.compactMap {
            Range($0.range(at: 1), in: caption).map { caption[$0].lowercased() }
        }))
    }

    private static func authError() -> NSError {
        NSError(domain: "Auth", code: -1,
                userInfo: [NSLocalizedDescriptionKey:"Not signed in"])
    }
    private static func imageError() -> NSError {
        NSError(domain: "Image", code: -1,
                userInfo: [NSLocalizedDescriptionKey:"Image conversion failed"])
    }
    private static func storageURLError() -> NSError {
        NSError(domain: "Storage", code: -1,
                userInfo: [NSLocalizedDescriptionKey:"No download URL"])
    }

    // Fetch weather data from OpenWeather
    private func fetchWeather(lat: Double, lon: Double,
                              completion: @escaping (String?, Double?) -> Void) {
        let key = Self.openWeatherKey
        guard !key.isEmpty else { completion(nil, nil); return }
        let urlStr = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(key)&units=metric"
        guard let url = URL(string: urlStr) else { completion(nil, nil); return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let res = try? JSONDecoder().decode(OpenWeatherResponse.self, from: data),
                  let icon = res.weather.first?.icon else {
                completion(nil, nil); return
            }
            completion(icon, res.main.temp)
        }.resume()
    }

    private struct OpenWeatherResponse: Decodable {
        struct Weather: Decodable { let icon: String }
        struct Main: Decodable { let temp: Double }
        let weather: [Weather]
        let main: Main
    }

    // decode Firestore → Post
    static func decodePost(doc: QueryDocumentSnapshot) -> Post? {
        let d = doc.data()
        guard
            let uid     = d["userId"]    as? String,
            let imgURL  = d["imageURL"]  as? String,
            let caption = d["caption"]   as? String,
            let ts      = d["timestamp"] as? Timestamp,
            let likes   = d["likes"]     as? Int
        else { return nil }

        let likedBy = d["likedBy"] as? [String] ?? []
        let me      = Auth.auth().currentUser?.uid
        let liked    = me.map { likedBy.contains($0) } ?? (d["isLiked"] as? Bool ?? false)

        return Post(
            id:           doc.documentID,
            userId:       uid,
            imageURL:     imgURL,
            caption:      caption,
            timestamp:    ts.dateValue(),
            likes:        likes,
            isLiked:      liked,
            latitude:     d["latitude"]  as? Double,
            longitude:    d["longitude"] as? Double,
            temp:         d["temp"]      as? Double,
            weatherIcon:  d["weatherIcon"] as? String,
            outfitItems:  parseOutfitItems(d["scanResults"]),
            outfitTags:   parseOutfitTags(d["outfitTags"]),
            hashtags:     d["hashtags"]  as? [String] ?? []
        )
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: Comment decoding shim (no FirebaseFirestoreSwift)
// ─────────────────────────────────────────────────────────────
extension Comment {
    static func fromFirestore(_ doc: QueryDocumentSnapshot) -> Comment? {
        let d = doc.data()
        guard
            let text = d["text"]       as? String,
            let uid  = d["userId"]     as? String,
            let ts   = d["timestamp"]  as? Timestamp
        else { return nil }

        return Comment(
            id:           doc.documentID,
            postId:       d["postId"] as? String ?? "",
            userId:       uid,
            username:     d["username"]     as? String ?? "",
            userPhotoURL: d["userPhotoURL"] as? String ?? "",
            text:         text,
            timestamp:    ts.dateValue()
        )
    }
}
