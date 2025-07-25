//  Replace file: ExploreView.swift
//  FitSpo
//
//  Phase 2.3 – hashtag filtering + full account-list mode
//  (works with the client-side search above).

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ExploreView: View {

    private let spacing: CGFloat = 2
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 120), spacing: spacing)]
    }

    // ────────── State ──────────
    @State private var allPosts:  [Post] = []
    @State private var posts:     [Post] = []
    @State private var lastDoc:   DocumentSnapshot?
    @State private var isLoading  = false

    @State private var trendingTags: [String] = []

    // search
    @State private var searchText = ""
    @State private var accountHits: [UserLite] = []
    @State private var isSearchingAccounts = false
    @State private var showResults = false
    @State private var selectedUserId: String? = nil

    @State private var hashtagSuggestions: [String] = []
    @State private var isSearchingHashtags = false
    @State private var showSuggestions = false

    // chips / filters
    @State private var selectedChip = "All"
    private let chips = ["All", "Men", "Women", "Street", "Formal"]

    @State private var filter      = ExploreFilter()
    @State private var showFilters = false

    @State private var selectedPost: Post? = nil

    private var isAccountMode: Bool {
        !searchText.isEmpty && searchText.first != "#"
    }

    // ────────── Body ──────────
    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    // Normal Explore content
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            chipRow
                            trendingTagsRow
                            grid
                        }
                    }
                } else {
                    // Search takes over the entire screen
                    searchContent
                }
            }
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if searchText.isEmpty {
                        Image(systemName: "slider.horizontal.3")
                            .onTapGesture { showFilters = true }
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                if searchText.isEmpty {
                    ExploreFilterSheet(filter: $filter)
                        .presentationDetents([.fraction(0.45)])
                }
            }
            .searchable(text: $searchText,
                        prompt: "Search accounts or #tags")
            .onSubmit(of: .search) { if !searchText.isEmpty { showResults = true; showSuggestions = false } }
            .onChange(of: searchText,  perform: handleSearchChange)
            .onChange(of: selectedChip) { _ in applyFilter() }
            .onChange(of: filter)       { _ in applyFilter() }
            .refreshable { await reload(clear: true) }
            .task        { await coldStart() }
            .navigationDestination(isPresented: $showResults) {
                SearchResultsView(query: searchText)
            }
            .navigationDestination(item: $selectedUserId) { userId in
                ProfileView(userId: userId)
            }
            .navigationDestination(item: $selectedPost) { post in
                PostDetailView(post: post)
            }
            .onChange(of: selectedUserId) { newValue in
                if newValue == nil && !searchText.isEmpty {
                    showSuggestions = true
                    Task { await fetchSuggestions() }
                }
            }
            .onAppear {
                if !searchText.isEmpty && selectedUserId == nil {
                    showSuggestions = true
                    Task { await fetchSuggestions() }
                }
            }
        }
    }

    // ────────── Load helpers ──────────
    private func coldStart() async {
        while !NetworkService.isOnline {
            try? await Task.sleep(for: .seconds(1))
        }
        await reload(clear: true)
    }

    private func reload(clear: Bool) async {
        if isLoading { return }
        if clear { allPosts.removeAll(); lastDoc = nil }
        isLoading = true
        defer { isLoading = false }

        do {
            let bundle = try await NetworkService.shared
                .fetchTrendingPosts(startAfter: lastDoc)
            lastDoc = bundle.lastDoc
            allPosts.append(contentsOf: bundle.posts)
            // Deduplicate by post.id
            var seen = Set<String>()
            allPosts = allPosts.filter { post in
                if seen.contains(post.id) { return false }
                seen.insert(post.id); return true
            }
            computeTrendingTags()
            applyFilter()
        } catch {
            print("Explore fetch error:", error.localizedDescription)
        }
    }

    private func loadMoreIfNeeded() async {
        guard !isLoading, lastDoc != nil, !isAccountMode else { return }
        await reload(clear: false)
        // Deduplicate after loading more
        var seen = Set<String>()
        allPosts = allPosts.filter { post in
            if seen.contains(post.id) { return false }
            seen.insert(post.id); return true
        }
    }

    // ────────── Trending tags ──────────
    private func computeTrendingTags() {
        let sevenDaysAgo =
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        var freq: [String:Int] = [:]
        for p in allPosts where p.timestamp >= sevenDaysAgo {
            for tag in p.hashtags { freq[tag, default: 0] += 1 }
        }
        trendingTags = freq
            .sorted { $0.value > $1.value }
            .prefix(12)
            .map { $0.key }
    }

    // ────────── Search callbacks ──────────
    private func handleSearchChange(_ q: String) {
        showSuggestions = !q.isEmpty
        Task {
            await fetchSuggestions()
        }
        applyFilter()
    }

    private func fetchSuggestions() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            accountHits = []
            hashtagSuggestions = []
            return
        }
        if trimmed.first == "#" {
            // Only hashtag suggestions
            isSearchingHashtags = true
            defer { isSearchingHashtags = false }
            let prefix = String(trimmed.dropFirst())
            do {
                hashtagSuggestions = try await NetworkService.shared.suggestHashtags(prefix: prefix)
            } catch {
                hashtagSuggestions = []
            }
            accountHits = []
        } else {
            // Both accounts and hashtags
            async let users: Void = {
                isSearchingAccounts = true
                defer { isSearchingAccounts = false }
                do {
                    accountHits = try await NetworkService.shared.searchUsers(prefix: trimmed)
                } catch {
                    accountHits = []
                }
            }()
            async let hashtags: Void = {
                isSearchingHashtags = true
                defer { isSearchingHashtags = false }
                do {
                    hashtagSuggestions = try await NetworkService.shared.suggestHashtags(prefix: trimmed)
                } catch {
                    hashtagSuggestions = []
                }
            }()
            _ = await (users, hashtags)
        }
    }

    // ────────── UI pieces ──────────
    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.subheadline)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(selectedChip == chip
                                    ? Color.black
                                    : Color(.systemGray5))
                        .foregroundColor(selectedChip == chip
                                         ? .white : .primary)
                        .clipShape(Capsule())
                        .onTapGesture { selectedChip = chip }
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(.vertical, 6)
    }

    private var trendingTagsRow: some View {
        Group {
            if !trendingTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(trendingTags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.subheadline)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                                .onTapGesture {
                                    searchText = "#" + tag
                                    showResults = true
                                }
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .padding(.bottom, 6)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(posts) { post in
                NavigationLink {
                    PostDetailView(post: post)
                } label: {
                    ImageTile(url: post.imageURL)
                }
                .onAppear {
                    if post.id == posts.last?.id {
                        Task { await loadMoreIfNeeded() }
                    }
                }
            }
        }
        .padding(.horizontal, spacing / 2)
        .padding(.bottom, spacing)
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 8) // Spacing below search bar
            
            if isSearchingAccounts || isSearchingHashtags {
                VStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Text("Searching...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if searchText.first == "#" {
                            // Only hashtags
                            if hashtagSuggestions.isEmpty {
                                VStack {
                                    Spacer()
                                    Text("No hashtags found")
                                        .foregroundColor(.secondary)
                                        .padding()
                                    Spacer()
                                }
                            } else {
                                ForEach(hashtagSuggestions, id: \.self) { tag in
                                    Button(action: {
                                        searchText = "#" + tag
                                        showResults = true
                                        showSuggestions = false
                                    }) {
                                        HStack(spacing: 12) {
                                            Text("#")
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text(tag)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 20)
                                    }
                                    .background(Color.clear)
                                }
                            }
                        } else {
                            // Both accounts and hashtags
                            if accountHits.isEmpty && hashtagSuggestions.isEmpty {
                                VStack {
                                    Spacer()
                                    Text("No results found")
                                        .foregroundColor(.secondary)
                                        .padding()
                                    Spacer()
                                }
                            } else {
                                // Accounts
                                ForEach(accountHits) { u in
                                    Button(action: {
                                        selectedUserId = u.id
                                        showSuggestions = false
                                    }) {
                                        HStack(spacing: 12) {
                                            AsyncImage(url: URL(string: u.avatarURL)) { phase in
                                                if let img = phase.image { img.resizable() }
                                                else { Color.gray.opacity(0.3) }
                                            }
                                            .frame(width: 36, height: 36)
                                            .clipShape(Circle())
                                            Text(u.displayName)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 20)
                                    }
                                    .background(Color.clear)
                                }
                                // Hashtags
                                ForEach(hashtagSuggestions, id: \.self) { tag in
                                    Button(action: {
                                        searchText = "#" + tag
                                        showResults = true
                                        showSuggestions = false
                                    }) {
                                        HStack(spacing: 12) {
                                            Text("#")
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text(tag)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 20)
                                    }
                                    .background(Color.clear)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 80) // Extra padding at bottom for scrolling
                }
            }
        }
    }

    // ────────── Filtering ──────────
    private func applyFilter() {
        var filtered = allPosts

        if let season = filter.season {
            filtered = filtered.filter { p in
                let m = Calendar.current.component(.month, from: p.timestamp)
                switch season {
                case .spring: return (3...5).contains(m)
                case .summer: return (6...8).contains(m)
                case .fall:   return (9...11).contains(m)
                case .winter: return m == 12 || m <= 2
                }
            }
        }

        if let band = filter.timeBand {
            filtered = filtered.filter { p in
                let h = Calendar.current.component(.hour, from: p.timestamp)
                switch band {
                case .morning:   return (5..<11).contains(h)
                case .afternoon: return (11..<17).contains(h)
                case .evening:   return (17..<21).contains(h)
                case .night:     return h >= 21 || h < 5
                }
            }
        }

        if selectedChip != "All" {
            let chip = selectedChip.lowercased()
            filtered = filtered.filter { $0.hashtags.contains(chip) }
        }

        if searchText.first == "#" {
            let tag = searchText.dropFirst().lowercased()
            filtered = filtered.filter { $0.hashtags.contains(tag) }
        }

        posts = filtered
    }
}

// ────────── Grid image tile ──────────
private struct ImageTile: View {
    let url: String
    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .empty:   Color.gray.opacity(0.12)
                case .success(let img): img.resizable().scaledToFill()
                case .failure: Color.gray.opacity(0.12)
                @unknown default: Color.gray.opacity(0.12)
                }
            }
            .frame(width: side, height: side)
            .clipped()
            .cornerRadius(8)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

//  End of file
