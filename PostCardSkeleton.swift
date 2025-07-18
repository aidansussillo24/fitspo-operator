import SwiftUI

struct PostCardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(4/5, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 14)
                    .cornerRadius(4)

                Spacer()

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 14)
                    .cornerRadius(4)
            }
            .padding(8)
            .background(Color.white)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

#if DEBUG
struct PostCardSkeleton_Previews: PreviewProvider {
    static var previews: some View {
        PostCardSkeleton()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
