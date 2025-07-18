//
//  AccountRow.swift
//  FitSpo
//

import SwiftUI

/// Re-usable row for followers lists **and** search results
struct AccountRow: View {
    let user: UserLite

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatarURL)) { phase in
                if let img = phase.image { img.resizable() }
                else { Color.gray.opacity(0.3) }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            Text(user.displayName)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
