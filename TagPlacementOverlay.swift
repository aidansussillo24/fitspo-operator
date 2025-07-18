//
//  TagPlacementOverlay.swift
//  FitSpo
//
//  Lets the creator drop & drag a pin on the image, then press **Done**
//  to return the normalised x/y to the caller.
//

import SwiftUI

struct TagPlacementOverlay: View {

    let baseImage: UIImage
    /// Handler called with xNorm / yNorm when the user taps **Done**.
    var onDone: (CGFloat, CGFloat) -> Void

    // local state
    @State private var currentPos: CGPoint? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()

                    Image(uiImage: baseImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width)
                        .onTapGesture { location in                 // first tap
                            currentPos = location
                        }

                    // movable pin
                    if let p = currentPos {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 20, height: 20)
                            .position(p)
                            .gesture(
                                DragGesture()
                                    .onChanged { currentPos = $0.location }
                            )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            guard let p = currentPos else { return }
                            let xNorm = p.x / geo.size.width
                            let yNorm = p.y / geo.size.width          // height == width
                            onDone(xNorm, yNorm)
                            dismiss()
                        }
                        .disabled(currentPos == nil)
                    }
                }
            }
            .navigationTitle("Place Tag")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
