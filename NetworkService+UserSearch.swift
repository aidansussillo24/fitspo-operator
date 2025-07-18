//  Replace file: NetworkService+UserSearch.swift
//  FitSpo
//
//  Client-side fallback search:
//  • pulls up to 50 user docs ordered by displayName
//  • does a case-insensitive prefix match in Swift
//  • requires **no** Firestore composite index or helper fields
//  • plenty fast for dev / small production datasets

import FirebaseFirestore

extension NetworkService {

    /// Returns up to 15 `UserLite` hits whose display name starts
    /// with the supplied prefix (case-insensitive).
    func searchUsers(prefix raw: String) async throws -> [UserLite] {

        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return [] }

        let lc = input.lowercased()

        // Pull first 50 docs – tweak limit if needed.
        let docs = try await db.collection("users")
            .order(by: "displayName")
            .limit(to: 50)
            .getDocuments()
            .documents

        return docs.compactMap { snap in
            let d = snap.data()
            guard
                let name = d["displayName"] as? String,
                name.lowercased().hasPrefix(lc)
            else { return nil }

            let url = d["avatarURL"] as? String ?? ""
            return UserLite(id: snap.documentID,
                            displayName: name,
                            avatarURL: url)
        }
        .prefix(15)
        .map { $0 }
    }
}
