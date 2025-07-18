import SwiftUI

struct ImageCropperView: View {
    let image: UIImage
    var onCropped: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1

    private let ratio: CGFloat = 1.25 // 4:5 aspect ratio

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let frameWidth = geo.size.width
                let frameHeight = frameWidth * ratio

                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: frameWidth, height: frameHeight)
                        .offset(x: offset.width + dragOffset.width,
                                y: offset.height + dragOffset.height)
                        .scaleEffect(scale * pinchScale)
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in
                                    state = value.translation
                                }
                                .onEnded { value in
                                    offset.width += value.translation.width
                                    offset.height += value.translation.height
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .updating($pinchScale) { value, state, _ in
                                    state = value
                                }
                                .onEnded { value in
                                    scale *= value
                                }
                        )
                        .clipped()
                        .overlay(
                            Rectangle().stroke(Color.white, lineWidth: 2)
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if let cropped = crop(in: frameWidth, height: frameHeight) {
                                onCropped(cropped)
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func crop(in width: CGFloat, height: CGFloat) -> UIImage? {
        let displayScale = scale
        let finalScale = displayScale * pinchScale
        // Image display size after scaling
        let dispW = width * finalScale
        let dispH = height * finalScale

        let x = (dispW - width)/2 - (offset.width + dragOffset.width)
        let y = (dispH - height)/2 - (offset.height + dragOffset.height)

        let xRatio = image.size.width / dispW
        let yRatio = image.size.height / dispH

        let cropRect = CGRect(x: x * xRatio,
                              y: y * yRatio,
                              width: width * xRatio,
                              height: height * yRatio)
        guard let cg = image.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cg)
    }
}
