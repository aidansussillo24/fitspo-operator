//
//  ZoomableAsyncImage.swift
//  FitSpo
//
//  Pinch‑to‑zoom image view used in PostDetailView.
//

import SwiftUI
import UIKit

struct ZoomableAsyncImage: UIViewRepresentable {
    let url: URL
    @Binding var aspectRatio: CGFloat?      // filled in once the image is downloaded

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate                   = context.coordinator
        scroll.maximumZoomScale           = 4
        scroll.minimumZoomScale           = 1
        scroll.bouncesZoom                = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator   = false

        // AsyncImage hosted inside the scroll‑view
        let host = UIHostingController(rootView:
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack { Color.gray.opacity(0.2); ProgressView() }
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fit)
                default:
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        )
        host.view.backgroundColor     = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(host.view)

        // width follows scroll; height has 1:1 placeholder until we know real ratio
        context.coordinator.height =
            host.view.heightAnchor.constraint(equalTo: host.view.widthAnchor, multiplier: 1)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scroll.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            context.coordinator.height!
        ])

        context.coordinator.zoomView = host.view
        context.coordinator.computeAspectRatio()
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    // MARK: – Coordinator --------------------------------------------------
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableAsyncImage
        weak var zoomView: UIView?
        var height: NSLayoutConstraint?
        private var didFetch = false

        init(_ parent: ZoomableAsyncImage) { self.parent = parent }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { zoomView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let v = zoomView else { return }
            let b = scrollView.bounds.size
            var f = v.frame
            f.origin.x = f.width  < b.width  ? (b.width  - f.width ) / 2 : 0
            f.origin.y = f.height < b.height ? (b.height - f.height) / 2 : 0
            v.frame = f
        }

        /// Reads the image once and fills in the real aspect‑ratio so the height stops jumping.
        func computeAspectRatio() {
            guard !didFetch else { return }
            didFetch = true
            DispatchQueue.global(qos: .userInitiated).async {
                guard
                    let data = try? Data(contentsOf: self.parent.url, options: .mappedIfSafe),
                    let img  = UIImage(data: data)
                else { return }
                let ratio = img.size.height / img.size.width
                DispatchQueue.main.async {
                    self.parent.aspectRatio = ratio
                    self.height?.isActive   = false
                    if let v = self.zoomView {
                        self.height =
                            v.heightAnchor.constraint(equalTo: v.widthAnchor, multiplier: ratio)
                        self.height?.isActive = true
                        v.setNeedsLayout(); v.layoutIfNeeded()
                    }
                }
            }
        }
    }
}
