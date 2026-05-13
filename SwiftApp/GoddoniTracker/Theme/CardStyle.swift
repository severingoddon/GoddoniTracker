import SwiftUI

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GTColor.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(GTColor.borderSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
