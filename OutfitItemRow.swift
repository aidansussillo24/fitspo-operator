//
//  OutfitItemRow.swift
//  FitSpo
//

import SwiftUI

struct OutfitItemRow: View {
    let item: OutfitItem

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: item.shopURL)) { phase in
                if let img = try? phase.image?.resizable() {
                    img.scaledToFill()
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).fontWeight(.semibold)
                if !item.brand.isEmpty {
                    Text(item.brand).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.up.right").foregroundColor(.secondary)
        }
        .contentShape(Rectangle())          // make full row tappable
    }
}
