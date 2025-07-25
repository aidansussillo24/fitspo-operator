//
//  SearchResultsView.swift
//  FitSpo
import Foundation

import SwiftUI
// Algolia removed – searches now use Firestore only

/// Stand‑alone screen shown when user taps a username / hashtag result.
struct SearchResultsView: View {
    let query: String                 // either "@sofia" or "#beach"
    @State private var users:  [UserLite] = []
    @State private var posts:  [Post]     = []
    @State private var isLoading         = true  // Start with loading true
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
            .onAppear {
                // Backup to ensure search runs
                if !isLoading && posts.isEmpty && users.isEmpty {
                    Task { await runSearch() }
                }
            }
        }
    }

    // ────────── Search orchestration ──────────
    @MainActor
    private func runSearch() async {
        // Ensure we're in loading state
        isLoading = true
        
        // Small delay to ensure UI is ready
        try? await Task.sleep(for: .milliseconds(100))
        
        defer { isLoading = false }

        if query.first == "@" {
            do {
                users = try await NetworkService.shared.searchUsers(prefix: query)
                print("Found \(users.count) users for query: \(query)")
            } catch {
                print("User search error:", error.localizedDescription)
                users = []
            }
        } else if query.first == "#" {
            await searchHashtag(String(query.dropFirst()))
        } else {
            await searchHashtag(query)
        }
        
        // Force UI update
        await MainActor.run {
            // Trigger a state change to force UI refresh
            isLoading = false
        }
    }

    @MainActor
    private func searchHashtag(_ tag: String) async {
        do {
            posts = try await NetworkService.shared.searchPosts(hashtag: tag)
            print("Found \(posts.count) posts for hashtag: \(tag)")
        } catch {
            print("Hashtag search error:", error.localizedDescription)
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
