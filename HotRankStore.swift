//
//  HotRankStore.swift
//  FitSpo
//
//  Simple daily cache that maps post-ID → rank (1…100).
//

import Foundation
import FirebaseFirestore

@MainActor
final class HotRankStore: ObservableObject {

    static let shared = HotRankStore()

    /// postId → rank (1-based)
    @Published private(set) var ranks: [String:Int] = [:]

    private var lastFetchDate: Date?

    /// Ensure we have today’s Top-100. Safe to call many times.
    func refreshIfNeeded() async {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastFetchDate,
           Calendar.current.isDate(last, inSameDayAs: today) { return }

        do {
            let bundle = try await NetworkService.shared
                .fetchHotPostsPage(startAfter: nil, limit: 100)

            var map: [String:Int] = [:]
            for (idx, post) in bundle.posts.enumerated() {
                map[post.id] = idx + 1
            }
            ranks = map
            lastFetchDate = today
        } catch {
            print("HotRankStore refresh error:", error.localizedDescription)
        }
    }

    /// Returns rank if the post is in today’s Top-100.
    func rank(for postId: String) -> Int? {
        ranks[postId]
    }
}
