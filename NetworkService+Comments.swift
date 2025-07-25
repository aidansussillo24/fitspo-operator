//
//  NetworkService+Comments.swift
//  FitSpo
//

import FirebaseFirestore

extension NetworkService {

    // MARK: – Add comment
    func addComment(to postId: String,
                    comment: Comment,
                    completion: @escaping (Result<Void,Error>) -> Void) {

        Firestore.firestore()
            .collection("posts").document(postId)
            .collection("comments").document(comment.id)
            .setData(comment.dictionary) { err in
                if let err = err { completion(.failure(err)) }
                else             { completion(.success(())) }
            }
    }

    // MARK: – Fetch comments (one-shot)
    func fetchComments(for postId: String,
                       completion: @escaping (Result<[Comment],Error>) -> Void) {

        Firestore.firestore()
            .collection("posts").document(postId)
            .collection("comments")
            .order(by: "timestamp")
            .getDocuments { snap, err in
                if let err = err { completion(.failure(err)); return }
                let comments = snap?.documents.compactMap {
                    Comment(from: $0.data())
                } ?? []
                completion(.success(comments))
            }
    }

    // MARK: – Update (edit) a comment
    func updateComment(postId: String,
                       commentId: String,
                       newText: String,
                       completion: @escaping (Result<Void,Error>) -> Void) {

        Firestore.firestore()
            .collection("posts").document(postId)
            .collection("comments").document(commentId)
            .updateData([
                "text": newText                       // keep original timestamp
            ]) { err in
                if let err = err { completion(.failure(err)) }
                else             { completion(.success(())) }
            }
    }

    // MARK: – Delete a comment
    func deleteComment(postId: String,
                       commentId: String,
                       completion: @escaping (Result<Void,Error>) -> Void) {

        Firestore.firestore()
            .collection("posts").document(postId)
            .collection("comments").document(commentId)
            .delete { err in
                if let err = err { completion(.failure(err)) }
                else             { completion(.success(())) }
            }
    }
    
    // MARK: – Like a comment
    func likeComment(postId: String,
                     commentId: String,
                     userId: String,
                     completion: @escaping (Result<Void,Error>) -> Void) {
        
        let commentRef = Firestore.firestore()
            .collection("posts").document(postId)
            .collection("comments").document(commentId)
        
        commentRef.updateData([
            "likedBy": FieldValue.arrayUnion([userId]),
            "likeCount": FieldValue.increment(Int64(1))
        ]) { err in
            if let err = err { completion(.failure(err)) }
            else             { completion(.success(())) }
        }
    }
    
    // MARK: – Unlike a comment
    func unlikeComment(postId: String,
                       commentId: String,
                       userId: String,
                       completion: @escaping (Result<Void,Error>) -> Void) {
        
        let commentRef = Firestore.firestore()
            .collection("posts").document(postId)
            .collection("comments").document(commentId)
        
        commentRef.updateData([
            "likedBy": FieldValue.arrayRemove([userId]),
            "likeCount": FieldValue.increment(Int64(-1))
        ]) { err in
            if let err = err { completion(.failure(err)) }
            else             { completion(.success(())) }
        }
    }
}
