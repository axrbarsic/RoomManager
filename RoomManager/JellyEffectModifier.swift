import SwiftUI

struct JellyEffectModifier: ViewModifier {
    @State private var offset: CGFloat = 0.0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("scrollView")).minY)
                }
            )
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.5)) {
                    offset = value
                }
            }
            .scaleEffect(y: 1 + scaleFactor(), anchor: .center)
    }
    
    private func scaleFactor() -> CGFloat {
        if offset > 0 {
            return min(offset / 300, 0.1)
        } else if offset < 0 {
            return min(abs(offset) / 300, 0.1)
        } else {
            return 0
        }
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0.0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func jellyEffect() -> some View {
        self.modifier(JellyEffectModifier())
    }
} 