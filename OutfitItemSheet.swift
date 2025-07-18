//
//  OutfitItemSheet.swift
//  FitSpo
//

import SwiftUI
import SafariServices

fileprivate func sanitizedURL(from raw: String) -> URL? {
    guard !raw.isEmpty else { return nil }
    if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
        return URL(string: raw)
    } else {
        return URL(string: "https://\(raw)")
    }
}

struct OutfitItemSheet: View {
    let items: [OutfitItem]
    @Binding var isPresented: Bool

    @State private var safariURL: URL? = nil

    var body: some View {
        NavigationStack {
            VStack {
                if items.isEmpty {
                    Spacer()
                    Image(systemName: "questionmark.square.dashed")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No outfit items")
                        .font(.headline)
                        .padding(.top, 4)
                    Spacer()
                } else {
                    List {
                        ForEach(items) { item in
                            if item.shopURL.isEmpty {
                                Text(item.label)
                            } else {
                                Button {
                                    safariURL = sanitizedURL(from: item.shopURL)
                                } label: {
                                    HStack {
                                        Text(item.label).fontWeight(.semibold)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Outfit details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }
}
