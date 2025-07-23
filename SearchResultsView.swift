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
                if query.first == "@" {
                    List {
                        ForEach(users) { u in
                            NavigationLink(destination: ProfileView(userId: u.id)) {
                                SearchAccountRow(user: u)
                            }
                        }
                    }

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
        } else if query.first == "#" {
            await searchHashtag(String(query.dropFirst()))
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

            // Perform the search and decode results manually. Removing the
            // `SearchResponse<Post>` generic resolves the build error on older
            // versions of Algolia's Swift SDK.
            let response = try await index.search(
                query: Query(query).set(\.hitsPerPage, to: 40)
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            posts = response.hits.reduce(into: [Post]()) { result, hit in
                // `Hit` from Algolia's Swift client stores record fields in
                // `additionalProperties`. Encoding the hit back to JSON gives us
                // a dictionary we can decode into `Post` without relying on
                // subscripting support, which may be missing on older
                // versions of the client.
                guard let hitData = try? JSONEncoder().encode(hit) else { return }
                guard var post = try? decoder.decode(Post.self, from: hitData) else { return }
                // Extract the object identifier from the hit using reflection
                let mirror = Mirror(reflecting: hit)
                if let id = mirror.children.first(where: { $0.label == "objectID" })?.value as? String {
                    post.objectID = id
                }
                result.append(post)
            }

        } catch {
            print("Algolia search error:", error.localizedDescription)
            posts = []
        }
    }

    @MainActor
    private func searchHashtag(_ tag: String) async {
        do {
            let client = SearchClient(appID: "6WFE31B7U3",
                                      apiKey: "2b7e223b3ca3c31fc6aaea704b80ca8c")
            let index = client.index(withName: "posts")

            let q = Query("")
                .set(\.filters, to: "hashtags:\(tag.lowercased())")
                .set(\.hitsPerPage, to: 40)

            let response = try await index.search(query: q)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            posts = response.hits.reduce(into: [Post]()) { result, hit in
                guard let data = try? JSONEncoder().encode(hit),
                      var post = try? decoder.decode(Post.self, from: data) else { return }
                let mirror = Mirror(reflecting: hit)
                if let id = mirror.children.first(where: { $0.label == "objectID" })?.value as? String {
                    post.objectID = id
                }
                result.append(post)
            }

            posts.sort { $0.likes > $1.likes }

            // Fallback to Firestore if Algolia returns no hits
            if posts.isEmpty {
                posts = try await NetworkService.shared
                    .searchPosts(hashtag: tag)
            }
        } catch {
            print("Algolia search error:", error.localizedDescription)
            do {
                posts = try await NetworkService.shared
                    .searchPosts(hashtag: tag)
            } catch {
                print("Firestore hashtag search error:", error.localizedDescription)
                posts = []
            }
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

/// A simple row used to display a user in search results. Defining this here
/// ensures account rows render even if the standalone `AccountRow.swift` file
/// isn't part of the build. It mirrors the original implementation from
/// `AccountRow.swift`.
struct SearchAccountRow: View {
    let user: UserLite
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatarURL)) { phase in
                if let img = phase.image { img.resizable() }
                else { Color.gray.opacity(0.3) }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            Text(user.displayName)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
