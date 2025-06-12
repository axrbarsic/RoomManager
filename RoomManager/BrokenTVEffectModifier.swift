import SwiftUI
import Combine

// MARK: - Модификатор упрощенного эффекта сломанного ТВ (без Metal)
struct SimpleBrokenTVEffectModifier: ViewModifier {
    @AppStorage("useParticleEffect") private var useParticleEffect = true
    @State private var noisePhase = 0.0
    @State private var glitchOffset = CGSize.zero
    @State private var scanlineOffset = 0.0
    @State private var showEffect = false
    
    // Обновленные настройки для более крупных частиц
    private let pixelSize: CGFloat = 8.0 // Увеличенный размер точек (было 4.0)
    private let refreshRate: Double = 0.04 // ~25 FPS - оптимизировано для производительности
    
    let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()
    
    func body(content: Content) -> some View {
        ZStack {
            if useParticleEffect && showEffect {
                // Фоновый шум
                ZStack {
                    // Фоновый цвет
                    Color.black.opacity(0.8)
                    
                    // Случайный шум - используем Canvas для лучшей производительности
                    NoiseBackgroundView(pixelSize: pixelSize)
                        .opacity(0.5)
                        .blendMode(.plusLighter)
                    
                    // Горизонтальные линии развертки
                    ScanlineBackgroundView(offset: scanlineOffset)
                        .opacity(0.3)
                    
                    // Случайные глитчи
                    GlitchBackgroundView(offset: glitchOffset)
                        .opacity(0.4)
                }
                .ignoresSafeArea() // Используем новый метод вместо устаревшего
                .onReceive(timer) { _ in
                    // Анимация шума и глитчей
                    withAnimation(.linear(duration: refreshRate)) {
                        // Случайное появление глитчей
                        if Double.random(in: 0...1) > 0.7 {
                            glitchOffset = CGSize(
                                width: CGFloat.random(in: -10...10),
                                height: 0
                            )
                        } else {
                            glitchOffset = .zero
                        }
                        
                        // Движение линий развертки
                        scanlineOffset += 0.5
                        
                        // Обновление фазы шума
                        noisePhase = Double.random(in: 0...1000)
                    }
                }
            }
            
            content
        }
        .onAppear {
            // Задержка для предотвращения лагов при появлении
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showEffect = true
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Компонент для создания шума с использованием Canvas
struct NoiseBackgroundView: View {
    let pixelSize: CGFloat
    @State private var seed = Int.random(in: 0...10000)
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Canvas { context, size in
            // Оптимизация: рисуем только крупные пиксели
            let rows = Int(size.height / pixelSize)
            let cols = Int(size.width / pixelSize)
            
            for r in 0..<rows {
                for c in 0..<cols {
                    if Bool.random() {
                        let x = CGFloat(c) * pixelSize
                        let y = CGFloat(r) * pixelSize
                        let rect = CGRect(x: x, y: y, width: pixelSize, height: pixelSize)
                        
                        let alpha = CGFloat.random(in: 0.1...0.7)
                        let gray = CGFloat.random(in: 0.5...1.0)
                        let color = Color(white: gray, opacity: alpha)
                        
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            seed = Int.random(in: 0...10000)
        }
        .id(seed) // Заставит Canvas перерисоваться при смене seed
    }
}

// Компонент для создания линий развертки
struct ScanlineBackgroundView: View {
    let offset: Double
    
    var body: some View {
        GeometryReader { geo in
            let lineCount = 15 // Меньше линий для лучшей производительности (было 25)
            let lineHeight = geo.size.height / CGFloat(lineCount)
            
            ForEach(0..<lineCount, id: \.self) { index in
                let yPos = CGFloat(index) * lineHeight + CGFloat(offset).truncatingRemainder(dividingBy: lineHeight)
                
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 2) // Более заметные линии (было 1)
                    .position(x: geo.size.width/2, y: yPos)
            }
        }
    }
}

// Компонент для создания глитч-эффектов
struct GlitchBackgroundView: View {
    let offset: CGSize
    
    var body: some View {
        GeometryReader { geo in
            let spacing = geo.size.height / 8 // Меньше линий для производительности (было 10)
            
            ForEach(0..<8, id: \.self) { index in
                if index % 2 == 0 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.1), .red.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: spacing)
                        .offset(offset)
                        .position(x: geo.size.width/2, y: spacing/2 + CGFloat(index) * spacing)
                }
            }
        }
    }
}

// Расширение для View
extension View {
    func simpleBrokenTVEffect() -> some View {
        self.modifier(SimpleBrokenTVEffectModifier())
    }
} 