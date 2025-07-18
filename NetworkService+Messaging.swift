// NetworkService+Messaging.swift

import Foundation
import FirebaseAuth
import FirebaseFirestore

extension NetworkService {
    /// Fetch all 1:1 chats for the current user, sorted by lastTimestamp desc.
    func fetchChats(completion: @escaping (Result<[Chat], Error>) -> Void) {
        guard let me = Auth.auth().currentUser?.uid else {
            // not signed in → empty list
            return completion(.success([]))
        }
        let db = Firestore.firestore()
        db.collection("chats")
          .whereField("participants", arrayContains: me)
          .order(by: "lastTimestamp", descending: true)
          .getDocuments { snap, err in
            if let err = err {
                return completion(.failure(err))
            }
            let chats = snap?.documents.compactMap { doc -> Chat? in
                let d = doc.data()
                guard
                    let parts   = d["participants"]   as? [String],
                    let lastMsg = d["lastMessage"]    as? String,
                    let ts      = d["lastTimestamp"]  as? Timestamp
                else { return nil }
                return Chat(
                    id:            doc.documentID,
                    participants:  parts,
                    lastMessage:   lastMsg,
                    lastTimestamp: ts.dateValue()
                )
            } ?? []
            completion(.success(chats))
        }
    }

    /// Listen for new messages in a chat (fires one callback per added message).
    @discardableResult
    func observeMessages(
        chatId: String,
        onNewMessage: @escaping (Result<Message, Error>) -> Void
    ) -> ListenerRegistration {
        let db = Firestore.firestore()
        return db.collection("chats")
            .document(chatId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snap, err in
                if let err = err {
                    return onNewMessage(.failure(err))
                }
                snap?.documentChanges.forEach { change in
                    guard change.type == .added else { return }
                    let doc = change.document
                    let d = doc.data()
                    guard
                        let sid = d["senderId"]   as? String,
                        let ts  = d["timestamp"]  as? Timestamp
                    else { return }
                    let msg = Message(
                        id:        doc.documentID,
                        senderId:  sid,
                        text:      d["text"]   as? String,
                        postId:    d["postId"] as? String,
                        timestamp: ts.dateValue()
                    )
                    onNewMessage(.success(msg))
                }
            }
    }

    /// Send a plain-text message
    func sendMessage(
        chatId: String,
        text: String,
        completion: @escaping (Error?) -> Void
    ) {
        guard let me = Auth.auth().currentUser?.uid else {
            return completion(NSError(
                domain: "",
                code:   -1,
                userInfo: [NSLocalizedDescriptionKey:"Not signed in"]
            ))
        }
        let db = Firestore.firestore()
        let data: [String:Any] = [
            "senderId":  me,
            "text":      text,
            "timestamp": Timestamp(date: Date())
        ]
        let msgRef = db.collection("chats")
            .document(chatId)
            .collection("messages")
            .document()
        msgRef.setData(data) { err in
            // bump preview
            db.collection("chats").document(chatId).updateData([
                "lastMessage":   text,
                "lastTimestamp": Timestamp(date: Date())
            ])
            completion(err)
        }
    }

    /// Send a post-share message
    func sendPost(
        chatId: String,
        postId: String,
        completion: @escaping (Error?) -> Void
    ) {
        guard let me = Auth.auth().currentUser?.uid else {
            return completion(NSError(
                domain: "",
                code:   -1,
                userInfo: [NSLocalizedDescriptionKey:"Not signed in"]
            ))
        }
        let db = Firestore.firestore()
        let data: [String:Any] = [
            "senderId":  me,
            "postId":    postId,
            "timestamp": Timestamp(date: Date())
        ]
        let msgRef = db.collection("chats")
            .document(chatId)
            .collection("messages")
            .document()
        msgRef.setData(data) { err in
            // bump preview
            db.collection("chats").document(chatId).updateData([
                "lastMessage":   "[Photo]",
                "lastTimestamp": Timestamp(date: Date())
            ])
            completion(err)
        }
    }

    /// Create (or fetch existing) 1:1 chat for exactly these two UIDs
    func createChat(
        participants: [String],
        completion: @escaping (Result<Chat, Error>) -> Void
    ) {
        let db     = Firestore.firestore()
        let sorted = participants.sorted()

        // 1) Try to find existing
        db.collection("chats")
          .whereField("participants", isEqualTo: sorted)
          .getDocuments { snap, err in
            if let err = err {
                return completion(.failure(err))
            }
            if let doc = snap?.documents.first {
                let d = doc.data()
                let chat = Chat(
                    id:            doc.documentID,
                    participants:  d["participants"] as? [String] ?? [],
                    lastMessage:   d["lastMessage"]  as? String   ?? "",
                    lastTimestamp: (d["lastTimestamp"] as? Timestamp)?.dateValue() ?? Date()
                )
                return completion(.success(chat))
            }
            // 2) Create new
            let now     = Timestamp(date: Date())
            let payload: [String:Any] = [
                "participants":  sorted,
                "lastMessage":   "",
                "lastTimestamp": now
            ]
            var ref: DocumentReference? = nil
            ref = db.collection("chats").addDocument(data: payload) { err in
                if let err = err { return completion(.failure(err)) }
                guard let id = ref?.documentID else {
                    return completion(.failure(NSError(
                        domain: "",
                        code:   -2,
                        userInfo: [NSLocalizedDescriptionKey:"Missing chat ID"]
                    )))
                }
                let chat = Chat(id:            id,
                                participants:  sorted,
                                lastMessage:   "",
                                lastTimestamp: now.dateValue())
                completion(.success(chat))
            }
        }
    }
}
