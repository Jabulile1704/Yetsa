import SwiftUI

struct AmbientBackground: View {
    @Environment(\.colorScheme) private var scheme

    private var intensity: Double { scheme == .dark ? 0.20 : 0.12 }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            blob(Color(hex: "E89A42"), size: 340, x: -140, y: -300)
            blob(.accentColor, size: 300, x: 170, y: -140)
            blob(Color(hex: "6C7FC4"), size: 360, x: -120, y: 320)
            blob(Color(hex: "57A877"), size: 270, x: 160, y: 440)
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(intensity))
            .frame(width: size, height: size)
            .blur(radius: 90)
            .offset(x: x, y: y)
    }
}
