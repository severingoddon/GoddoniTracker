import SwiftUI

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(GTColor.bgElevated.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(GTColor.borderSubtle, lineWidth: 1)
            )
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}
