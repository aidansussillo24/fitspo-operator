//
//  PostDetailView.swift
//  FitSpo
//
//  Displays one post, its pins, likes & comments.
//  *2025-07-01*  • Hot-rank badge redesign: larger circle, gradient,
//                 bold number overlay for better legibility.
//  *2025-07-02*  • Auto-detect rank via HotRankStore so badge shows
//                 on every PostDetailView, not just Hot-Posts feed.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import UIKit

// ─────────────────────────────────────────────────────────────
struct PostDetailView: View {

    // ── injected
    let post: Post
    let rank: Int?
    let navTitle: String
    @Environment(\.dismiss) private var dismiss

    // ── author
    @State private var authorName      = ""
    @State private var authorAvatarURL = ""
    @State private var isLoadingAuthor = true

    // ── geo
    @State private var locationName = ""

    // ── like / comments
    @State private var isLiked: Bool
    @State private var likesCount: Int
    @State private var showHeart = false
    @State private var commentCount = 0
    @State private var showComments = false

    // ── share
    @State private var showShareSheet = false
    @State private var shareChat: Chat?
    @State private var navigateToChat = false

    // ── delete / report
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var showReportSheet  = false

    // ── outfit pins
    @State private var outfitItems : [OutfitItem]
    @State private var outfitTags  : [OutfitTag]
    @State private var showPins    = false          // default OFF
    @State private var expandedTag : String? = nil
    @State private var showOutfitSheet = false

    // ── misc
    @State private var postListener: ListenerRegistration?
    @State private var imgRatio: CGFloat? = nil     // natural h/w
    @State private var faceTags: [UserTag] = []
    @State private var dynamicRank: Int? = nil      // fetched from cache
    @State private var showHashtagResults = false
    @State private var currentHashtagQuery: String = ""
    @State private var isLoadingHashtag = false
    @State private var selectedUserId: String = ""
    @State private var showUserProfile = false
    @State private var isLoadingMention = false

    init(post: Post, rank: Int? = nil, navTitle: String = "Post") {
        self.post = post
        self.rank = rank
        self.navTitle = navTitle
        _isLiked     = State(initialValue: post.isLiked)
        _likesCount  = State(initialValue: post.likes)
        _outfitItems = State(initialValue: post.outfitItems ?? [])
        _outfitTags  = State(initialValue: post.outfitTags  ?? [])
    }

    // =========================================================
    // MARK: body
    // =========================================================
    var body: some View {
        ZStack(alignment: .bottom) {

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    postImage            // <──── fixed-height now
                    actionRow
                    captionRow
                    timestampRow
                    Spacer(minLength: 32)
                }
                .padding(.top)
            }

            if showComments {
                CommentsOverlay(
                    post: post,
                    isPresented: $showComments,
                    onCommentCountChange: { commentCount = $0 },
                    onHashtagTap: { hashtag in
                        handleHashtagTap(hashtag)
                    },
                    onMentionTap: { username in
                        handleMentionTap(username)
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut, value: showComments)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Post?", isPresented: $showDeleteConfirm,
               actions: deleteAlertButtons)
        .overlay { if isDeleting { deletingOverlay } }
        .sheet(isPresented: $showShareSheet)  { shareSheet }
        .sheet(isPresented: $showOutfitSheet) {
            OutfitItemSheet(items: outfitItems,
                            isPresented: $showOutfitSheet)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(postId: post.id,
                            isPresented: $showReportSheet)
        }
        .background { chatNavigationLink }
        .task { await ensureHotRank() }
        .onAppear   { attachListenersAndFetch() }
        .onDisappear{ postListener?.remove() }
        .sheet(isPresented: $showHashtagResults) {
            SearchResultsView(query: currentHashtagQuery)
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationStack {
                ProfileView(userId: selectedUserId)
            }
        }
        .overlay {
            if isLoadingHashtag || isLoadingMention {
                Color.black.opacity(0.3)
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(isLoadingHashtag ? "Loading hashtag..." : "Looking up user...")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .padding(20)
                        .background(.ultraThickMaterial)
                        .cornerRadius(12)
                    }
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: ----------------------------------------------------
    // MARK: header
    // MARK: ----------------------------------------------------
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(destination: ProfileView(userId: post.userId)) {
                avatarView
            }
            VStack(alignment: .leading, spacing: 4) {
                NavigationLink(destination: ProfileView(userId: post.userId)) {
                    Text(isLoadingAuthor ? "Loading…" : authorName)
                        .font(.headline)
                }
                if !locationName.isEmpty {
                    Text(locationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            weatherIconView
        }
        .padding(.horizontal)
    }

    // MARK: ----------------------------------------------------
    // MARK: main image (height capped at 4:5)
    // MARK: ----------------------------------------------------
    private var postImage: some View {
        GeometryReader { geo in
            if let url = URL(string: post.imageURL) {

                // determine which ratio to display (natural vs capped)
                let naturalRatio = imgRatio ?? 1                // h / w
                let displayRatio = min(naturalRatio, 1.25)      // cap at 4:5
                let displayHeight = UIScreen.main.bounds.width * displayRatio

                ZoomableAsyncImage(url: url, aspectRatio: $imgRatio)
                    .frame(width: geo.size.width, height: displayHeight)
                    .clipped()
                    .highPriorityGesture(
                        TapGesture(count: 2).onEnded { handleDoubleTapLike() }
                    )
                    .overlay { faceTagOverlay(in: geo, ratio: displayRatio) }
                    .overlay { if showPins { outfitPins(in: geo, ratio: displayRatio) } }
                    .overlay(HeartBurstView(trigger: $showHeart))
                    // shopping-bag toggle (bottom-left corner)
                    .overlay(alignment: .bottomLeading) {
                        Button {
                            if outfitItems.isEmpty { showOutfitSheet = true }
                            else { showPins.toggle() }
                        } label: {
                            Image(systemName: showPins ? "bag.fill" : "bag")
                                .font(.system(size: 17, weight: .semibold))
                                .padding(12)
                                .background(.ultraThickMaterial, in: Circle())
                        }
                        .padding(16)
                    }
                    // hot rank badge (bottom-right corner)
                    .overlay(alignment: .bottomTrailing) {
                        hotBadge
                    }
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(height: UIScreen.main.bounds.width * min(imgRatio ?? 1, 1.25))
    }

    // MARK: overlays
    private func faceTagOverlay(in geo: GeometryProxy, ratio: CGFloat) -> some View {
        ForEach(faceTags) { tag in
            NavigationLink(destination: ProfileView(userId: tag.id)) {
                Text(tag.displayName)
                    .font(.caption2.weight(.semibold))
                    .padding(6)
                    .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .position(
                x: tag.xNorm * geo.size.width,
                y: tag.yNorm * geo.size.width * ratio
            )
        }
    }

    private func outfitPins(in geo: GeometryProxy, ratio: CGFloat) -> some View {
        ForEach(outfitTags) { t in
            if let item = outfitItems.first(where: { $0.id == t.itemId }) {
                let expanded = expandedTag == t.id

                Group {
                    if expanded {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label).bold()
                            if !item.brand.isEmpty {
                                Text(item.brand)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !item.shopURL.isEmpty {
                                Button("Buy") {
                                    if let url = URL(string: item.shopURL) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(8)
                        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .onTapGesture { expandedTag = nil }
                    } else {
                        Text(item.label)
                            .font(.caption2.weight(.semibold))
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .onTapGesture { expandedTag = t.id }
                    }
                }
                .animation(.spring(), value: expandedTag)
                .position(
                    x: t.xNorm * geo.size.width,
                    y: t.yNorm * geo.size.width * ratio
                )
            }
        }
    }

    // MARK: – Hot-rank badge  (new design)
    @ViewBuilder private var hotBadge: some View {
        if let rank = rank ?? dynamicRank {
            let size: CGFloat = 36

            ZStack {
                // gradient background – “heat”
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.62, blue: 0.13),   // #FF9F21
                                     Color(red: 1.0, green: 0.35, blue: 0.13)],  // #FF5921
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing)
                    )

                // subtle flame watermark
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .opacity(0.25)
                    .foregroundColor(.white)

                // rank number
                Text("\(rank)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 0.5)
            }
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
            .padding(16)
        }
    }

    // MARK: action row ----------------------------------------
    private var actionRow: some View {
        HStack(spacing: 24) {
            Button(action: toggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(isLiked ? .red : .primary)
            }
            Text("\(likesCount)").font(.subheadline.bold())

            Button { showComments = true } label: {
                Image(systemName: "bubble.right").font(.title2)
            }
            Text("\(commentCount)").font(.subheadline.bold())

            Button { showShareSheet = true } label: {
                Image(systemName: "paperplane").font(.title2)
            }
            Menu {
                if post.userId == Auth.auth().currentUser?.uid {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) { showReportSheet = true } label: {
                        Label("Report", systemImage: "flag")
                    }
                }
            } label: {
                Image(systemName: "ellipsis").font(.title2)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: caption / time rows --------------------------------
    private var captionRow: some View {
        HStack(alignment: .top, spacing: 4) {
            NavigationLink(destination: ProfileView(userId: post.userId)) {
                Text(isLoadingAuthor ? "Loading…" : authorName)
                    .fontWeight(.semibold)
            }
            ClickableHashtagText(text: post.caption) { hashtag in
                handleHashtagTap(hashtag)
            } onMentionTap: { username in
                handleMentionTap(username)
            }
        }
        .padding(.horizontal)
    }

    private var timestampRow: some View {
        Text(post.timestamp, style: .time)
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.horizontal)
    }

    // MARK: avatar helper --------------------------------------
    @ViewBuilder private var avatarView: some View {
        Group {
            if let url = URL(string: authorAvatarURL), !authorAvatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill").resizable()
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    // MARK: weather helper ------------------------------------
    @ViewBuilder private var weatherIconView: some View {
        if let name = post.weatherSymbolName {
            HStack(spacing: 4) {
                if let temp = post.tempString {
                    Text(temp)
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                if let (primary, secondary) = post.weatherIconColors {
                    if let secondary = secondary {
                        Image(systemName: name)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(primary, secondary)
                    } else {
                        Image(systemName: name)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(primary)
                    }
                } else {
                    Image(systemName: name)
                }
            }
            .padding(6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    // MARK: like helpers ---------------------------------------
    private func toggleLike() {
        isLiked.toggle()
        likesCount += isLiked ? 1 : -1
        NetworkService.shared.toggleLike(post: post) { _ in }
    }

    private func handleDoubleTapLike() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        showHeart = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showHeart = false }
        if !isLiked { toggleLike() }
    }

    // MARK: delete / report ------------------------------------
    private func performDelete() {
        isDeleting = true
        NetworkService.shared.deletePost(id: post.id) { res in
            DispatchQueue.main.async {
                isDeleting = false
                if case .success = res { dismiss() }
            }
        }
    }

    @ViewBuilder private func deleteAlertButtons() -> some View {
        Button("Delete", role: .destructive, action: performDelete)
        Button("Cancel",  role: .cancel) { }
    }

    private var deletingOverlay: some View {
        ProgressView("Deleting…")
            .padding()
            .background(.regularMaterial,
                        in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: share helpers --------------------------------------
    private var shareSheet: some View {
        ShareToUserView { uid in
            showShareSheet = false
            sharePost(to: uid)
        }
    }

    private func sharePost(to uid: String) {
        guard let me = Auth.auth().currentUser?.uid else { return }
        let pair = [me, uid].sorted()
        NetworkService.shared.createChat(participants: pair) { res in
            switch res {
            case .success(let chat):
                NetworkService.shared.sendPost(chatId: chat.id,
                                               postId: post.id) { _ in }
                DispatchQueue.main.async {
                    shareChat = chat
                    navigateToChat = true
                }
            case .failure(let err):
                print("Chat creation error:", err.localizedDescription)
            }
        }
    }

    private var chatNavigationLink: some View {
        Group {
            if let chat = shareChat {
                NavigationLink(destination: ChatDetailView(chat: chat),
                               isActive: $navigateToChat) { EmptyView() }
                    .hidden()
            }
        }
    }

    // MARK: Firestore helpers ----------------------------------
    private func attachListenersAndFetch() {
        attachPostListener()
        fetchAuthor()
        fetchLocationName()
        fetchCommentCount()
        fetchFaceTags()
    }

    private func attachPostListener() {
        guard postListener == nil else { return }
        postListener = Firestore.firestore()
            .collection("posts")
            .document(post.id)
            .addSnapshotListener { snap, _ in
                guard let d = snap?.data() else { return }
                likesCount   = d["likes"]         as? Int ?? likesCount
                commentCount = d["commentsCount"] as? Int ?? commentCount

                if let likedBy = d["likedBy"] as? [String],
                   let uid = Auth.auth().currentUser?.uid {
                    isLiked = likedBy.contains(uid)
                }

                outfitItems = NetworkService.parseOutfitItems(d["scanResults"])
                outfitTags  = NetworkService.parseOutfitTags (d["outfitTags"])
            }
    }

    private func fetchAuthor() {
        Firestore.firestore().collection("users")
            .document(post.userId)
            .getDocument { snap, _ in
                isLoadingAuthor = false
                let d = snap?.data() ?? [:]
                authorName      = d["displayName"] as? String ?? "Unknown"
                authorAvatarURL = d["avatarURL"]   as? String ?? ""
            }
    }

    private func fetchLocationName() {
        guard let lat = post.latitude, let lon = post.longitude else { return }
        let loc = CLLocation(latitude: lat, longitude: lon)
        CLGeocoder().reverseGeocodeLocation(loc) { places, _ in
            locationName = places?.first?.locality ?? ""
        }
    }

    private func fetchCommentCount() {
        NetworkService.shared.fetchComments(for: post.id) { res in
            if case .success(let list) = res { commentCount = list.count }
        }
    }

    private func fetchFaceTags() {
        NetworkService.shared.fetchTags(for: post.id) { res in
            if case .success(let list) = res { faceTags = list }
        }
    }

    // Fetch Top‑100 if needed and update dynamicRank
    private func ensureHotRank() async {
        await HotRankStore.shared.refreshIfNeeded()
        if let r = HotRankStore.shared.rank(for: post.id) {
            dynamicRank = r
        }
    }

    private func handleHashtagTap(_ hashtag: String) {
        isLoadingHashtag = true
        
        Task {
            // Set the query
            currentHashtagQuery = "#\(hashtag)"
            
            // Show loading for a moment to ensure everything is set up
            try? await Task.sleep(for: .milliseconds(500))
            
            // Hide loading and show results
            isLoadingHashtag = false
            showHashtagResults = true
        }
    }
    
    private func handleMentionTap(_ username: String) {
        // Validate username before navigation
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't navigate if username is empty or invalid
        guard !cleanUsername.isEmpty else {
            print("Warning: Empty username tapped, ignoring")
            return
        }
        
        isLoadingMention = true
        
        // Look up the actual userId for this username
        print("Looking up userId for username: \(cleanUsername)")
        NetworkService.shared.lookupUserId(username: cleanUsername) { userId in
            DispatchQueue.main.async {
                isLoadingMention = false
                
                if let userId = userId {
                    print("Found userId: \(userId) for username: \(cleanUsername)")
                    selectedUserId = userId
                    showUserProfile = true
                } else {
                    print("No user found with username: \(cleanUsername)")
                    // Could show an alert or error message to user
                }
            }
        }
    }
}
