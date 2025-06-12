import SwiftUI

struct FloatingMarkerViewModifier: ViewModifier {
    var isMarked: Bool
    var roomColor: Room.RoomColor // не используется, но оставим для совместимости
    
    // Параметры квадратной рамки
    private let borderThickness: CGFloat = 8.0
    private let glowThickness: CGFloat = 20.0
    private let borderInsetRatio: CGFloat = 0.18 // Отступ рамки от краёв ячейки
    private let arcFraction: CGFloat = 0.33 // Доля периметра, занимаемая дугой (0.33 = 1/3 рамки)
    private let speed: CGFloat = 1.0 // оборотов в секунду
    
    // Радужный градиент (7 цветов)
    private let rainbowColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .red
    ]
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .overlay(
                    GeometryReader { geometry in
                        if isMarked {
                            let size = geometry.size
                            let minSide = min(size.width, size.height)
                            let inset = minSide * borderInsetRatio
                            let rect = CGRect(x: inset, y: inset, width: size.width - 2*inset, height: size.height - 2*inset)
                            let perim = 2 * (rect.width + rect.height)
                            let arcLen = perim * arcFraction
                            TimelineView(.animation) { timeline in
                                let time = timeline.date.timeIntervalSinceReferenceDate
                                let phase = CGFloat(time * Double(speed)).truncatingRemainder(dividingBy: 1.0)
                                let start = (phase * perim).truncatingRemainder(dividingBy: perim)
                                let end = (start + arcLen).truncatingRemainder(dividingBy: perim)
                                let arcPath = squareArcPath(rect: rect, perim: perim, start: start, end: end)
                                Canvas { context, _ in
                                    context.stroke(
                                        arcPath,
                                        with: .linearGradient(
                                            Gradient(colors: rainbowColors),
                                            startPoint: rect.origin,
                                            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                                        ),
                                        style: StrokeStyle(lineWidth: glowThickness, lineCap: .round)
                                    )
                                    context.blendMode = .plusLighter
                                    context.stroke(
                                        arcPath,
                                        with: .linearGradient(
                                            Gradient(colors: rainbowColors),
                                            startPoint: rect.origin,
                                            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                                        ),
                                        style: StrokeStyle(lineWidth: borderThickness, lineCap: .round)
                                    )
                                }
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .blur(radius: isMarked ? 3.0 : 0)
                    .animation(.easeInOut, value: isMarked)
                )
        }
    }
    
    // Строит путь дуги по квадрату (от start до end по периметру)
    private func squareArcPath(rect: CGRect, perim: CGFloat, start: CGFloat, end: CGFloat) -> Path {
        var path = Path()
        // Функция для получения точки на периметре по длине
        func point(at len: CGFloat) -> CGPoint {
            let l = len.truncatingRemainder(dividingBy: perim)
            if l < rect.width { // верхняя грань left->right
                return CGPoint(x: rect.minX + l, y: rect.minY)
            } else if l < rect.width + rect.height { // правая грань top->bottom
                return CGPoint(x: rect.maxX, y: rect.minY + (l - rect.width))
            } else if l < 2*rect.width + rect.height { // нижняя грань right->left
                return CGPoint(x: rect.maxX - (l - rect.width - rect.height), y: rect.maxY)
            } else { // левая грань bottom->top
                return CGPoint(x: rect.minX, y: rect.maxY - (l - 2*rect.width - rect.height))
            }
        }
        let step: CGFloat = 2.0
        var l = start
        path.move(to: point(at: l))
        while true {
            l += step
            if (start < end && l > end) || (start > end && l > perim + end) { break }
            path.addLine(to: point(at: l))
        }
        return path
    }
}

extension View {
    func floatingMarker(isMarked: Bool, roomColor: Room.RoomColor) -> some View {
        self.modifier(FloatingMarkerViewModifier(isMarked: isMarked, roomColor: roomColor))
    }
} 