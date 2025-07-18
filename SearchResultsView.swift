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

            // Perform the search (async/await is built‑in from v8 onwards)
            let response = try await index.search(
                query: Query(query).set(\.hitsPerPage, to: 40)
            )

            // `response.hits` is `[Hit<JSON>]`.  The SDK gives us a helper to
            // turn each hit into a strongly‑typed model:
                 // `response.hits` is `[Hit<JSON>]`. Decode each hit into a Post using JSONSerialization and JSONDecoder.
            posts = response.hits.compactMap { hit -> Post? in
                // Convert the raw JSON dictionary into Data.
                guard let data = try? JSONSerialization.data(withJSONObject: hit.json, options: []),
                      var post = try? JSONDecoder().decode(Post.self, from: data) else {
                    return nil
                }
                // If Algolia returns an objectID separately, store it on the model.
                if let id = hit.objectID?.rawValue {
                    post.objectID = id
                }
                retun post
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
