import SwiftUI

struct PulseEffectModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 0.92)
            .opacity(isPulsing ? 1.0 : 0.55)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .drawingGroup(opaque: true)
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulseEffect() -> some View {
        self.modifier(PulseEffectModifier())
    }
} 