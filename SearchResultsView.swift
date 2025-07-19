//
//  SearchResultsView.swift
//  FitSpo
import Foundation

import SwiftUI
import AlgoliaSearchClient            // v8+ of the Swift API client

/// Stand‑alone screen shown when user taps a username / hashtag result.
struct SearchResultsView: View {
    let query: String                 // either "@sofia" or "#beach"
    @State private var users:  [UserLite] = []
    @State private var posts:  [Post]     = []
    @State private var isLoading         = false
    @Environment(\.dismiss) private var dismiss

    // Masonry split columns like HomeView
    private var leftColumn : [Post] { posts.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element) }
    private var rightColumn: [Post] { posts.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element) }

    // ────────── UI ──────────
    var body: some View {
        NavigationStack {
            Group {
                // 1️⃣  Hashtags (future work)
                if query.first == "#" {
                    List {
                        Text("Hashtag search coming next…")
                            .foregroundColor(.secondary)
                    }

                // 2️⃣  Accounts
                } else if query.first == "@" {
                    List {
                        ForEach(users) { u in
                            NavigationLink(destination: ProfileView(userId: u.id)) {
                                AccountRow(user: u)
                            }
                        }
                    }

                // 3️⃣  Posts (default)
                } else {
                    ScrollView {
                        if isLoading {
                            ProgressView().padding(.top, 40)
                        } else if posts.isEmpty {
                            Text("No results found")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        } else {
                            HStack(alignment: .top, spacing: 8) {
                                column(for: leftColumn)
                                column(for: rightColumn)
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
            }
            .navigationTitle(query)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
            }}
            .task { await runSearch() }
        }
    }

    // ────────── Search orchestration ──────────
    @MainActor
    private func runSearch() async {
        isLoading = true
        defer { isLoading = false }

        if query.first == "@" {
            do {
                users = try await NetworkService.shared.searchUsers(prefix: query)
            } catch {
                print("User search error:", error.localizedDescription)
            }
        } else {
            await searchPosts()
        }
    }

    // MARK: –‑ Posts search (Algolia)
    @MainActor
    private func searchPosts() async {
        do {
            // Initialise the client *once*; credentials are already public in the repo
            let client = SearchClient(appID: "6WFE31B7U3",
                                      apiKey: "2b7e223b3ca3c31fc6aaea704b80ca8c")
            let index  = client.index(withName: "posts")

            // Perform a typed search. `SearchResponse<Post>` returns hits whose
            // `object` property is already a strongly‑typed `Post`. This avoids
            // having to decode JSON manually and resolves the `hit.json` error.
            let response: SearchResponse<Post> = try await index.search(
                query: Query(query).set(\.hitsPerPage, to: 40),
                as: Post.self
            )

            // Map each hit to a `Post` value. Because `SearchResponse<Post>`
            // returns `Hit<Post>` values, we can extract the `object` and
            // assign the Algolia `objectID` if present.
            posts = response.hits.compactMap { hit in
                var post = hit.object
                // Preserve Algolia's objectID (handy for updates / deletes).
                if let id = hit.objectID?.rawValue {
                    post.objectID = id
                }
                return post
            }

        } catch {
            print("Algolia search error:", error.localizedDescription)
            posts = []
        }
    }

    // ────────── Helpers ──────────
    @ViewBuilder
    private func column(for list: [Post]) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(list) { post in
                PostCardView(post: post, onLike: {})
            }
        }
    }
}
