import SwiftUI

struct ToastView: View {
    var message: String
    @Binding var isShowing: Bool
    var duration: Double = 2.0
    
    var body: some View {
        VStack {
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.indigo.opacity(0.8),
                                    Color.purple.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .foregroundColor(Color.white)
                .cornerRadius(10)
                .padding(.top, 15)
                .padding(.horizontal, 16)
            
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isShowing = false
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
} 