import SwiftUI

/// How full a window is. Overbooked bars fill completely and turn red rather
/// than running off the edge, because "more than full" is the only fact that
/// matters once you are past the end.
struct BudgetBar: View {
    let fraction: Double
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary.opacity(0.6))

                Capsule()
                    .fill(Palette.load(fraction, scheme))
                    .frame(width: proxy.size.width * min(1, max(0.02, fraction)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Small label pill used across the Today header.
struct Chip: View {
    let text: String
    var symbol: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.45), in: .capsule)
    }
}
