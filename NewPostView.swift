//  Replace file: NewPostView.swift
//  FitSpo
//
//  • Starts LocationManager when Post flow opens.
//  • 3-column grid with 1-pt separators (Instagram style).
//  • Preview collapses on scroll.

import SwiftUI
import PhotosUI

private struct OffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct NewPostView: View {

    // PhotoKit
    @State private var assets: [PHAsset] = []
    private let manager = PHCachingImageManager()

    // Selection
    @State private var selected : PHAsset?
    @State private var preview  : UIImage?
    @State private var showCropper = false
    @State private var collapsed = false
    @State private var showCaption = false

    // Start location updates as soon as this view appears
    @StateObject private var locationManager = LocationManager.shared

    // Grid
    private var sep: CGFloat { 1 / UIScreen.main.scale }
    private var cols: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: sep), count: 3) }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // -------- Preview ----------
                Group {
                    if let img = preview {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .overlay(alignment: .bottomTrailing) {
                                Button(action: { showCropper = true }) {
                                    Image(systemName: "crop")
                                        .font(.system(size: 14, weight: .bold))
                                        .padding(6)
                                        .background(Color.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                        .padding(6)
                                }
                            }
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: collapsed ? 0 : 300)
                .clipped()
                .cornerRadius(12)
                .overlay(alignment: .top) {
                    if collapsed && preview != nil {
                        Image(systemName: "chevron.compact.up")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                            .onTapGesture {
                                withAnimation { collapsed = false }
                            }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if preview != nil {
                        Button(action: { showCropper = true }) {
                            Image(systemName: "crop")
                                .font(.system(size: 14, weight: .bold))
                                .padding(6)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .padding(6)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: collapsed)
                .padding(.horizontal)
                .padding(.top, 8)

                // -------- Library label -----
                HStack {
                    Text("Photo Library")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .frame(height: collapsed ? 0 : nil)
                .clipped()
                .opacity(collapsed ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: collapsed)

                // -------- Grid -------------
                ScrollView {
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: OffsetKey.self,
                                        value: geo.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)

                    LazyVGrid(columns: cols, spacing: sep) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            Thumb(asset: asset,
                                  manager: manager,
                                  selected: asset == selected) {
                                select(asset)
                            }
                        }
                    }
                }
                .background(Color(.systemGray6))
                .onPreferenceChange(OffsetKey.self) { y in
                    if y < -20 && !collapsed {
                        withAnimation { collapsed = true }
                    } else if y > 0 && collapsed {
                        withAnimation { collapsed = false }
                    }
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") { showCaption = true }
                        .disabled(preview == nil)
                }
            }
            .background(
                NavigationLink(isActive: $showCaption) {
                    if let img = preview {
                        PostCaptionView(image: img) {
                            dismiss()
                        }
                    }
                } label: { EmptyView() }.hidden()
            )
            .sheet(isPresented: $showCropper) {
                if let img = preview {
                    ImageCropperView(image: img) { cropped in
                        preview = cropped
                    }
                }
            }
            .task(loadAssets)
            .coordinateSpace(name: "scroll")
        }
    }

    // MARK: – Load PhotoKit
    private func loadAssets() async {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return }

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 60
        let fetch = PHAsset.fetchAssets(with: .image, options: opts)

        var tmp: [PHAsset] = []
        fetch.enumerateObjects { a, _, _ in tmp.append(a) }
        assets = tmp
        if let first = assets.first { select(first) }
    }

    private func select(_ asset: PHAsset) {
        selected  = asset
        collapsed = false
        let size  = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        manager.requestImage(for: asset,
                             targetSize: size,
                             contentMode: .aspectFit,
                             options: nil) { img, _ in
            preview = img
        }
    }
}

// MARK: – Thumbnail with thin border
fileprivate struct Thumb: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    let selected: Bool
    let onTap: () -> Void

    @State private var img: UIImage?
    private var side: CGFloat {
        let sep = 1 / UIScreen.main.scale
        return (UIScreen.main.bounds.width - sep * 2) / 3
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let t = img {
                Image(uiImage: t)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipped()
            } else {
                Color.gray.opacity(0.15)
                    .frame(width: side, height: side)
            }

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.black)
                    .padding(4)
            }
        }
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray4).opacity(0.5), lineWidth: 1 / UIScreen.main.scale)
        )
        .onAppear(perform: loadThumb)
        .onTapGesture { onTap() }
    }

    private func loadThumb() {
        guard img == nil else { return }
        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 300, height: 300),
                             contentMode: .aspectFill,
                             options: nil) { i, _ in img = i }
    }
}
