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

    private let db = Firestore.firestore()

    // Two-column post grid
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    avatarSection                                          // avatar

                    // Name / @username / email / bio
                    VStack(spacing: 4) {
                        Text(displayName).font(.title2).bold()
                        if !username.isEmpty {
                            Text("@\(username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if isMe, !email.isEmpty {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if !bio.isEmpty {
                            Text(bio)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }

                    // Stats
                    HStack(spacing: 32) {
                        navStat(count: followersCount, label: "Followers",
                                destination: FollowersView(userId: userId))
                        navStat(count: followingCount, label: "Following",
                                destination: FollowingView(userId: userId))
                        statView(count: posts.count, label: "Posts")
                    }

                    // Buttons
                    if isMe {
                        Button("Edit Profile") { showingEdit = true }
                            .buttonStyle(.borderedProminent)
                            .padding(.top)
                    } else {
                        Button(isFollowing ? "Unfollow" : "Follow") {
                            toggleFollow()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)

                        Button {
                            openChat()
                        } label: {
                            Label("Message", systemImage: "bubble.left.and.bubble.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Divider().padding(.vertical, 8)

                    // Posts grid
                    if isLoadingPosts {
                        ProgressView().scaleEffect(1.5).padding()
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(posts) { post in
                                NavigationLink {
                                    PostDetailView(post: post)
                                } label: {
                                    PostCell(post: post)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 16)
            }
            .navigationTitle(displayName.isEmpty ? "Profile" : displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") { try? Auth.auth().signOut() }
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

    // MARK: – Computed helpers ------------------------------------
    private var isMe: Bool { userId == Auth.auth().currentUser?.uid }

    // MARK: – Avatar
    private var avatarSection: some View {
        Group {
            if let url = URL(string: avatarURL), !avatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:   ProgressView()
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .resizable()
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 16)
    }

    // MARK: – Stat helpers
    private func statView(count: Int, label: String) -> some View {
        VStack {
            Text("\(count)").font(.headline)
            Text(label).font(.caption)
        }
    }

    @ViewBuilder
    private func navStat<Dest: View>(count: Int, label: String, destination: Dest) -> some View {
        NavigationLink(destination: destination) {
            statView(count: count, label: label).foregroundColor(.black)
        }
        .buttonStyle(PlainButtonStyle())
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

//  End of file
