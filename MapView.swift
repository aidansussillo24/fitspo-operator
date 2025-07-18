// MapView.swift
// Shows all geo-tagged posts on a tappable map.

import SwiftUI
import MapKit

struct MapView: View {
    @State private var allPosts: [Post] = []
    @State private var posts:    [Post] = []
    @State private var filter    = MapFilter()
    @State private var showFilters = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749,
                                       longitude: -122.4194),
        span:   MKCoordinateSpan(latitudeDelta:  0.2,
                                 longitudeDelta: 0.2)
    )

    var body: some View {
        // 1️⃣ Filter to only those posts with non-nil coords
        let geoPosts = posts.filter { $0.latitude != nil && $0.longitude != nil }

        return NavigationView {
            Map(
                coordinateRegion: $region,
                annotationItems: geoPosts
            ) { post -> MapAnnotation in               // ← note the explicit return type
                // 2️⃣ Now it's safe to force-unwrap
                let coord = CLLocationCoordinate2D(
                    latitude:  post.latitude!,
                    longitude: post.longitude!
                )

                // 3️⃣ **RETURN** your annotation here
                return MapAnnotation(coordinate: coord) {
                    NavigationLink(destination: PostDetailView(post: post)) {
                        AsyncImage(url: URL(string: post.imageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Color.gray
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .shadow(radius: 3)
                    }
                }
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .onTapGesture { showFilters = true }
                }
            }
            .sheet(isPresented: $showFilters) {
                MapFilterSheet(filter: $filter)
                    .presentationDetents([.fraction(0.45)])
            }
            .onChange(of: filter) { _ in applyFilter() }
            .onAppear {
                NetworkService.shared.fetchPosts { result in
                    if case .success(let allPosts) = result {
                        self.allPosts = allPosts
                        applyFilter()

                        // center on first geo-tagged post, if any
                        if let first = allPosts.first,
                           let lat   = first.latitude,
                           let lng   = first.longitude
                        {
                            region.center = CLLocationCoordinate2D(
                                latitude:  lat,
                                longitude: lng
                            )
                        }
                    }
                }
            }
        }
    }

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

        if let band = filter.tempBand {
            filtered = filtered.filter { p in
                guard let c = p.temp else { return false }
                let f = c * 9 / 5 + 32
                switch band {
                case .cold: return f < 40
                case .cool: return f >= 40 && f < 60
                case .warm: return f >= 60 && f < 80
                case .hot:  return f >= 80
                }
            }
        }

        if let w = filter.weather {
            filtered = filtered.filter { p in
                guard let sym = p.weatherSymbolName else { return false }
                switch w {
                case .sunny:  return sym == "sun.max" || sym == "cloud.sun"
                case .cloudy: return sym.hasPrefix("cloud")
                }
            }
        }

        posts = filtered
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
