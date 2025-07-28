//  Replace file: ProfileView.swift
//  FitSpo
//
//  • Shows @username under display name.
//  • Adds init(userId:) so existing NavigationLinks that pass a userId
//    still compile, while MainTabView can call ProfileView() with no args.

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct ProfileView: View {

    // MARK: – Init (flexible) ------------------------------------
    init(userId: String? = nil) {
        self.userId = userId ?? Auth.auth().currentUser?.uid ?? ""
    }

    // The user ID whose profile is shown
    let userId: String

    // MARK: – State
    @State private var displayName   = ""
    @State private var username      = ""
    @State private var bio           = ""
    @State private var avatarURL     = ""
    @State private var email         = ""
    @State private var posts: [Post] = []
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var isFollowing    = false
    @State private var isLoadingPosts = false
    @State private var errorMessage   = ""
    @State private var showingEdit    = false

    // Messaging
    @State private var activeChat: Chat?
    @State private var showChat = false
    
    // Tab state
    @State private var selectedTab = 0 // 0=Posts, 1=Tagged, 2=Saved

    private let db = Firestore.firestore()

    // Three-column post grid (Instagram style)
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // FitSpo Profile Header
                    profileHeaderSection
                    
                    // Content Tabs & Grid
                    contentSection
                }
            }
            .navigationTitle(displayName.isEmpty ? "Profile" : displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isMe {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Sign Out") { try? Auth.auth().signOut() }
                    }
                }
            }
            .sheet(isPresented: $showingEdit) { EditProfileView() }
            .background(
                Group {
                    if let chat = activeChat {
                        NavigationLink(
                            destination: ChatDetailView(chat: chat),
                            isActive: $showChat
                        ) { EmptyView() }
                    }
                }
            )
            .onAppear(perform: loadEverything)
        }
    }
    
    // MARK: - FitSpo Profile Header
    private var profileHeaderSection: some View {
        VStack(spacing: 0) {
            // Top section with centered avatar
            VStack(spacing: 16) {
                // Centered avatar with fashion-inspired styling
                avatarSection
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .pink.opacity(0.3), .orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                // Name and bio
                VStack(spacing: 8) {
                    Text(displayName.isEmpty ? "Loading..." : displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if !username.isEmpty {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 20)
                    }
                    
                    if isMe, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Stats Row
                HStack(spacing: 40) {
                    navStat(count: posts.count, label: "Posts", destination: EmptyView())
                    navStat(count: followersCount, label: "Followers", destination: FollowersView(userId: userId))
                    navStat(count: followingCount, label: "Following", destination: FollowingView(userId: userId))
                }
                .padding(.horizontal, 20)
                
                // Action Buttons
                HStack(spacing: 12) {
                    if isMe {
                        Button("Edit Style Profile") { showingEdit = true }
                            .buttonStyle(FitSpoButtonStyle(isPrimary: false))
                        
                        Button("Share Profile") { }
                            .buttonStyle(FitSpoButtonStyle(isPrimary: false))
                        
                    } else {
                        Button(isFollowing ? "Following" : "Follow") {
                            toggleFollow()
                        }
                        .buttonStyle(FitSpoButtonStyle(isPrimary: !isFollowing))
                        
                        Button("Message") {
                            openChat()
                        }
                        .buttonStyle(FitSpoButtonStyle(isPrimary: false))
                    }
                }
                .padding(.horizontal, 20)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 0) {
            // Fashion-focused tabs
            HStack(spacing: 0) {
                tabButton(index: 0, icon: "grid", label: "OUTFITS")
                tabButton(index: 1, icon: "tag", label: "TAGGED")  
                tabButton(index: 2, icon: "heart", label: "SAVED")
            }
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .bottom
            )
            
            // Content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    postsGrid
                case 1:
                    taggedContent
                case 2:
                    savedContent
                default:
                    postsGrid
                }
            }
        }
    }
    
    private func tabButton(index: Int, icon: String, label: String) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundColor(selectedTab == index ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(selectedTab == index ? .primary : .clear),
                alignment: .bottom
            )
        }
    }
    
    private var postsGrid: some View {
        Group {
            if isLoadingPosts {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(60)
            } else if posts.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "hanger")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No Outfits Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Start sharing your style! Your outfit posts will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(60)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(posts) { post in
                        NavigationLink {
                            PostDetailView(post: post)
                        } label: {
                            PostCell(post: post)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    private var taggedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "tag")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No Tagged Posts")
                .font(.title2)
                .fontWeight(.bold)
            Text("Posts you're tagged in will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(60)
    }
    
    private var savedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No Saved Posts")
                .font(.title2)
                .fontWeight(.bold)
            Text("Save outfit inspiration to view here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(60)
    }

    // MARK: – Computed helpers ------------------------------------
    private var isMe: Bool { userId == Auth.auth().currentUser?.uid }

    // MARK: – Avatar
    private var avatarSection: some View {
        Group {
            if let url = URL(string: avatarURL), !avatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:   
                        ProgressView()
                            .frame(width: 100, height: 100)
                    case .success(let img):
                        img.resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: – Stat helpers
    private func statView(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func navStat<Dest: View>(count: Int, label: String, destination: Dest) -> some View {
        if label == "Posts" {
            statView(count: count, label: label)
        } else {
            NavigationLink(destination: destination) {
                statView(count: count, label: label)
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: – Private loading / actions -------------------------------------
private extension ProfileView {

    func loadEverything() {
        loadProfile()
        loadUserPosts()
        loadFollowState()
        loadFollowCounts()
    }

    func loadProfile() {
        email = Auth.auth().currentUser?.email ?? ""
        Firestore.firestore().collection("users").document(userId)
            .getDocument { snap, err in
                guard err == nil, let d = snap?.data() else { return }
                displayName = d["displayName"] as? String ?? ""
                username    = d["username"]    as? String ?? ""
                bio         = d["bio"]         as? String ?? ""
                avatarURL   = d["avatarURL"]   as? String ?? ""
            }
    }

    func loadUserPosts() {
        isLoadingPosts = true
        NetworkService.shared.fetchPosts { result in
            DispatchQueue.main.async {
                isLoadingPosts = false
                if case .success(let all) = result {
                    posts = all.filter { $0.userId == userId }
                }
            }
        }
    }

    func loadFollowState() {
        NetworkService.shared.isFollowing(userId: userId) { r in
            if case .success(let f) = r { isFollowing = f }
        }
    }

    func loadFollowCounts() {
        NetworkService.shared.fetchFollowCount(userId: userId,
                                               type: "followers") { r in
            if case .success(let c) = r { followersCount = c }
        }
        NetworkService.shared.fetchFollowCount(userId: userId,
                                               type: "following") { r in
            if case .success(let c) = r { followingCount = c }
        }
    }

    func toggleFollow() {
        let action = isFollowing
            ? NetworkService.shared.unfollow
            : NetworkService.shared.follow
        action(userId) { err in
            if err == nil {
                isFollowing.toggle()
                loadFollowCounts()
            }
        }
    }

    func openChat() {
        guard let me = Auth.auth().currentUser?.uid else { return }
        NetworkService.shared.fetchChats { result in
            guard case .success(let chats) = result else { return }
            if let existing = chats.first(where: {
                $0.participants.contains(me) && $0.participants.contains(userId)
            }) {
                activeChat = existing
                showChat   = true
            } else {
                NetworkService.shared
                    .createChat(participants: [me, userId]) { res in
                        if case .success(let chat) = res {
                            activeChat = chat
                            showChat   = true
                        }
                    }
            }
        }
    }
}

// MARK: - FitSpo Button Styles
struct FitSpoButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isPrimary ? .white : .primary)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color(.systemGray5)
                    }
                }
            )
            .cornerRadius(18)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
