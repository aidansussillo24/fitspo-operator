//
//  NetworkService+Reports.swift
//  FitSpo
//
//  Extension that lets any signed‑in user file a report.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension NetworkService {

    /// Writes one document into `/reports` keyed by "\(postId)_\(uid)".
    func submitReport(postId: String,
                      reason: ReportReason,
                      completion: @escaping (Result<Void,Error>) -> Void) {

        // -----------------------------------------------------------------
        // Use a local error so we don’t touch the private `authError()` in
        // the main file (that method is scoped `private` to its file).
        // -----------------------------------------------------------------
        guard let uid = Auth.auth().currentUser?.uid else {
            let err = NSError(domain: "Auth", code: -1,
                              userInfo: [NSLocalizedDescriptionKey:"Not signed in"])
            return completion(.failure(err))
        }

        let docId = "\(postId)_\(uid)"
        let data: [String: Any] = [
            "postId"     : postId,
            "reporterId" : uid,
            "reason"     : reason.rawValue,
            "timestamp"  : Timestamp(date: Date())
        ]

        db.collection("reports").document(docId).setData(data) { err in
            if let err { completion(.failure(err)) }
            else       { completion(.success(())) }
        }
    }
}
