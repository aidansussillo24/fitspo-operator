import SwiftUI

// MARK: Heart confetti burst  ───────────────────────────────
struct HeartBurstView: View {
    @Binding var trigger: Bool
    private let petals = Array(0..<6)

    var body: some View {
        ZStack {
            // central pop
            Image(systemName: "heart.fill")
                .resizable()
                .frame(width: 120, height: 120)
                .foregroundColor(.red)
                .scaleEffect(trigger ? 1.2 : 0.3)
                .opacity(trigger ? 1 : 0)                // 🟢 was inverted
                .animation(.easeOut(duration: 0.45), value: trigger)

            // mini hearts
            ForEach(petals, id: \.self) { i in
                Image(systemName: "heart.fill")
                    .resizable()
                    .frame(width: 26, height: 26)
                    .foregroundColor(.red)
                    .offset(x: trigger ? burstX(i) : 0,
                            y: trigger ? burstY(i) : 0)
                    .opacity(trigger ? 1 : 0)            // 🟢 was inverted
                    .scaleEffect(trigger ? 1 : 0.3)
                    .animation(.easeOut(duration: 0.45), value: trigger)
            }
        }
        .allowsHitTesting(false)   // don’t block taps
    }

    // spokes for the small hearts
    private func burstX(_ i: Int) -> CGFloat {
        let a: [CGFloat] = [20, 55, 110, 160, 205, 330]
        return 150 * cos(a[i] * .pi / 180)
    }
    private func burstY(_ i: Int) -> CGFloat {
        let a: [CGFloat] = [20, 55, 110, 160, 205, 330]
        return 150 * sin(a[i] * .pi / 180)
    }
}
