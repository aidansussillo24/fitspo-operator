//
//  TagOverlayView.swift
//  FitSpo
//
//  Full‑screen editor for adding & positioning user‑tags atop a photo.
//

import SwiftUI
import FirebaseFirestore

struct TagOverlayView: View {
    
    let baseImage: UIImage
    private let imgAspect: CGFloat          // h ÷ w
    
    // Existing tags
    @State private var tags: [UserTag]
    
    // Search sheet state
    @State private var showSearchSheet = false
    @State private var query   = ""
    @State private var results: [(id:String,name:String)] = []
    
    // Point awaiting a username (normalised 0…1)
    @State private var pendingPoint: (CGFloat,CGFloat)? = nil
    
    // Callback when user hits Done / Cancel
    var onDone: ([UserTag]) -> Void
    
    init(baseImage: UIImage,
         existing: [UserTag],
         onDone: @escaping ([UserTag]) -> Void) {
        self.baseImage = baseImage
        self.imgAspect = baseImage.size.height / baseImage.size.width
        _tags  = State(initialValue: existing)
        self.onDone = onDone
    }
    
    // ─────────────────────────────────────────────────────────────
    // MARK:  UI
    // ─────────────────────────────────────────────────────────────
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let fullW = geo.size.width
                let dispH = fullW * imgAspect
                let topPad = max((geo.size.height - dispH) / 2, 0)
                let imgSize = CGSize(width: fullW, height: dispH)
                
                ZStack(alignment: .topLeading) {
                    
                    // 1️⃣  Photo
                    Image(uiImage: baseImage)
                        .resizable()
                        .frame(width: fullW, height: dispH)
                        .clipped()
                        .contentShape(Rectangle())
                        .offset(y: topPad)
                        // tap → open search sheet
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { g in
                                    let loc = g.location
                                    guard loc.y >= topPad &&
                                          loc.y <= topPad + dispH else { return }
                                    let xN = loc.x / fullW
                                    let yN = (loc.y - topPad) / dispH
                                    pendingPoint = (xN, yN)
                                    showSearchSheet = true
                                }
                        )
                    
                    // 2️⃣  Editable tag labels
                    ForEach(tags.indices, id:\.self) { idx in
                        TagLabelView(
                            tag: $tags[idx],
                            parentSize: imgSize,
                            topPadding: topPad
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDone(tags) }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDone(tags) }.fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showSearchSheet, onDismiss: resetSearch) {
                SearchUserSheet(
                    query: $query,
                    results: $results,
                    onSelect: { uid, name in
                        addTag(uid: uid, name: name)
                        resetSearch()
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    private func addTag(uid: String, name: String) {
        guard let pt = pendingPoint else { return }
        tags.append(UserTag(id: uid,
                            xNorm: pt.0,
                            yNorm: pt.1,
                            displayName: name))
    }
    
    private func resetSearch() {
        query = ""; results = []; pendingPoint = nil; showSearchSheet = false
    }
}

// ─────────────────────────────────────────────────────────────
// MARK:  Draggable label
// ─────────────────────────────────────────────────────────────
private struct TagLabelView: View {
    
    @Binding var tag: UserTag
    var parentSize: CGSize          // size of displayed image
    var topPadding: CGFloat         // distance from top of screen
    
    @State private var offset: CGSize = .zero
    
    var body: some View {
        Text(tag.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .offset(offset)
            .position(
                x: tag.xNorm * parentSize.width,
                y: topPadding + tag.yNorm * parentSize.height
            )
            .gesture(
                DragGesture()
                    .onChanged { g in offset = g.translation }
                    .onEnded   { _ in
                        // Update normalised coords
                        let newAbsX = tag.xNorm * parentSize.width  + offset.width
                        let newAbsY = tag.yNorm * parentSize.height + offset.height
                        tag.xNorm = min(max(newAbsX / parentSize.width , 0), 1)
                        tag.yNorm = min(max(newAbsY / parentSize.height, 0), 1)
                        offset = .zero
                    }
            )
    }
}

// ─────────────────────────────────────────────────────────────
// MARK:  Username / Display‑name search
// ─────────────────────────────────────────────────────────────
private struct SearchUserSheet: View {
    @Binding var query: String
    @Binding var results: [(id:String,name:String)]
    var onSelect: (String,String) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(results, id:\.id) { r in
                    Button { onSelect(r.id, r.name) } label: { Text(r.name) }
                }
            }
            .navigationTitle("Tag someone")
            .searchable(text: $query, prompt: "Username or name")
            .onChange(of: query) { _ in fetch() }
        }
    }
    
    private func fetch() {
        let trimmed = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        guard trimmed.count >= 2 else { results = []; return }
        
        let users = Firestore.firestore().collection("users")
        var collected: [(String,String)] = []
        let grp = DispatchGroup()
        
        // username_lc
        grp.enter()
        users.whereField("username_lc", isGreaterThanOrEqualTo: trimmed)
             .whereField("username_lc", isLessThan: trimmed + "\u{f8ff}")
             .limit(to: 10)
             .getDocuments { snap, _ in
                 collected.append(contentsOf:
                    snap?.documents.map {
                        ($0.documentID, $0["displayName"] as? String ?? "user")
                    } ?? [])
                 grp.leave()
             }
        // displayName_lc
        grp.enter()
        users.whereField("displayName_lc", isGreaterThanOrEqualTo: trimmed)
             .whereField("displayName_lc", isLessThan: trimmed + "\u{f8ff}")
             .limit(to: 10)
             .getDocuments { snap, _ in
                 collected.append(contentsOf:
                    snap?.documents.map {
                        ($0.documentID, $0["displayName"] as? String ?? "user")
                    } ?? [])
                 grp.leave()
             }
        
        grp.notify(queue: .main) {
            var seen = Set<String>(); var unique:[(String,String)] = []
            for item in collected where !seen.contains(item.0) {
                seen.insert(item.0); unique.append(item)
                if unique.count == 10 { break }
            }
            results = unique
        }
    }
}
