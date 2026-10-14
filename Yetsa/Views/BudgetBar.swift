import SwiftUI

/// A hairline-thin progress bar. Two tones: what is already done, then what is
/// still planned against the window. The remainder is what is left over.
struct ThinBar: View {
    /// Fraction of the whole that is finished.
    var done: Double = 0
    /// Fraction that is planned but not yet done.
    var pending: Double = 0
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.primary)
                    .frame(width: proxy.size.width * clamped(done))

                Rectangle()
                    .fill(.tertiary)
                    .frame(width: proxy.size.width * clamped(pending))

                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .background(Color(.systemFill))
        .clipShape(.rect(cornerRadius: height / 2))
        .accessibilityHidden(true)
    }

    private func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
