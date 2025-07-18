//
//  PostCaptionView.swift
//  FitSpo
//
//  Create caption, face-tags, and manual outfit items & pins.
//

import SwiftUI
import CoreLocation

struct PostCaptionView: View {

    let image: UIImage
    var onComplete: (() -> Void)? = nil

    // caption & posting
    @State private var caption   = ""
    @State private var isPosting = false
    @State private var errorMsg: String?

    // face-tags
    @State private var tags: [UserTag] = []
    @State private var showTagOverlay  = false

    // outfit items & pins
    @State private var items:  [OutfitItem] = []
    @State private var oTags:  [OutfitTag]  = []

    @State private var showItemForm  = false
    @State private var editIndex: Int? = nil

    @State private var showTagPlacer   = false
    @State private var pendingItemId: String? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)

            // caption + face-tag button
            HStack {
                TextField("Enter a caption…", text: $caption, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)

                Button { showTagOverlay = true } label: {
                    Label("Tag", systemImage: "tag")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6), in: Capsule())
                }
            }

            if !tags.isEmpty {
                Text("\(tags.count) people tagged")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // ───────── Outfit items section ─────────
            VStack(spacing: 8) {
                HStack {
                    Text("Outfit items").font(.headline)
                    Spacer()
                    Button {
                        editIndex = nil
                        showItemForm = true
                    } label: { Image(systemName: "plus") }
                }

                if items.isEmpty {
                    Text("No items added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(it.label).fontWeight(.semibold)
                                if !it.brand.isEmpty {
                                    Text(it.brand)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button {                      // edit
                                editIndex = idx
                                showItemForm = true
                            } label: { Image(systemName: "pencil") }

                            Button(role: .destructive) { // delete
                                items.remove(at: idx)
                                oTags.removeAll { $0.itemId == it.id }
                            } label: { Image(systemName: "trash") }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))

            if let err = errorMsg {
                Text(err).foregroundColor(.red)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("New Post")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismissToRoot() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Post") { upload() }.disabled(isPosting)
            }
        }

        // face-tag overlay
        .fullScreenCover(isPresented: $showTagOverlay) {
            TagOverlayView(
                baseImage: image,
                existing: tags,
                onDone: { tags = $0; showTagOverlay = false }
            )
        }

        // outfit item form
        .sheet(isPresented: $showItemForm) {
            OutfitItemFormView(
                initial: editIndex.flatMap { items[$0] },
                onSave: { newItem in
                    let id = newItem.id
                    if let i = editIndex {
                        items[i] = newItem
                    } else {
                        items.append(newItem)
                    }
                    pendingItemId = id
                    showItemForm  = false
                    showTagPlacer = true
                },
                onCancel: { showItemForm = false }
            )
        }

        // pin placement overlay
        .fullScreenCover(isPresented: $showTagPlacer) {
            TagPlacementOverlay(
                baseImage: image
            ) { x, y in
                guard let id = pendingItemId else { return }
                oTags.append(OutfitTag(
                    id: UUID().uuidString,
                    itemId: id,
                    xNorm: x, yNorm: y
                ))
                pendingItemId = nil
            }
        }
    }

    // =========================================================
    // MARK: upload
    // =========================================================
    private func upload() {
        isPosting = true
        errorMsg  = nil

        let loc = LocationManager.shared.location
        let lat = loc?.coordinate.latitude
        let lon = loc?.coordinate.longitude

        NetworkService.shared.uploadPost(
            image: image,
            caption: caption,
            latitude: lat,
            longitude: lon,
            tags: tags,
            outfitItems: items,
            outfitTags: oTags
        ) { res in
            isPosting = false
            switch res {
            case .success: dismissToRoot()
            case .failure(let err): errorMsg = err.localizedDescription
            }
        }
    }

    private func dismissToRoot() {
        dismiss()
        onComplete?()
    }
}
