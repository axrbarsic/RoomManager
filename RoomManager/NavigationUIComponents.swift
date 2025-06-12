import SwiftUI
import AVFoundation
import Combine
import MetalKit
import Metal
import simd

// MARK: - Ключ предпочтений для отслеживания скролла
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Менеджер навигационной панели
class NavigationBarManager {
    static let shared = NavigationBarManager()
    
    private init() {}
    
    // Используемые в приложении отступы
    static let globalHorizontalPadding: CGFloat = 10
    static let bannerHorizontalPadding: CGFloat = 10
    
    // Размытый фон для наложения баннера
    func applyBlurredAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.shadowColor = .clear
        
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Прозрачный фон при обычном скролле
    func applyTransparentAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Стандартный вид (используется при необходимости)
    func applyDefaultAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

// MARK: - Вспомогательные расширения и модификаторы

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func highFPS() -> some View {
        self.modifier(HighFPSModifier())
    }
    
    // Добавляем новый модификатор для контроля границ
    func boundedWidth(safetyMargin: CGFloat = 5.0) -> some View {
        modifier(BoundedWidthModifier(safetyMargin: safetyMargin))
    }
    
    // Функция для центрирования контента на экране с правильными отступами
    func centeredWithPadding(horizontalPadding: CGFloat? = nil) -> some View {
        let padding = horizontalPadding ?? NavigationBarManager.globalHorizontalPadding
        return self
            .frame(width: UIScreen.main.bounds.width - padding * 2)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // Функция для применения оптимизированного фона с эффектом сломанного ТВ вместо частиц
    func optimizedBrokenTVBackground(
        noiseIntensity: Float = 0.8,
        scanlineIntensity: Float = 0.5,
        glitchIntensity: Float = 0.6,
        colorDistortion: Float = 0.4
    ) -> some View {
        self.modifier(
            BrokenTVBackground(
                noiseIntensity: noiseIntensity,
                scanlineIntensity: scanlineIntensity,
                glitchIntensity: glitchIntensity,
                colorDistortion: colorDistortion
            )
        )
    }
    
    // Функция для условного применения эффекта сломанного ТВ
    func conditionalTVBackground() -> some View {
        self.modifier(ConditionalTVBackground())
    }

    // Функция для использования упрощенного эффекта вместо Metal, если возникли проблемы
    func simpleTVEffect() -> some View {
        self.modifier(SimpleTVEffect())
    }
}

class DisplayLinkManager: NSObject, ObservableObject {
    @Published private var displayLink: CADisplayLink?
    
    @objc func handleDisplayLink(_ link: CADisplayLink) {
        // Всегда поддерживаем максимальную частоту обновления 120 Гц
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 120, maximum: 120, preferred: 120)
    }
    
    func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 120, maximum: 120, preferred: 120)
        displayLink?.add(to: .main, forMode: .tracking)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func userInteracted() {
        // Оставляем метод для совместимости, но ничего не делаем
    }
}

struct HighFPSModifier: ViewModifier {
    @StateObject private var displayLinkManager = DisplayLinkManager()
    
    func body(content: Content) -> some View {
        content
            .onAppear { displayLinkManager.startDisplayLink() }
            .onDisappear { displayLinkManager.stopDisplayLink() }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        displayLinkManager.userInteracted()
                    }
            )
    }
}

// Модификатор для контроля ширины и предотвращения выхода за границы экрана
struct BoundedWidthModifier: ViewModifier {
    let safetyMargin: CGFloat
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .frame(width: min(geometry.size.width - (safetyMargin * 2), UIScreen.main.bounds.width - (safetyMargin * 2)))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

// Модификатор для условного применения фона сломанного ТВ
struct ConditionalTVBackground: ViewModifier {
    @AppStorage("useParticleEffect") private var useParticleEffect = true
    @State private var useSimpleEffect = false
    @StateObject private var tvSettings = TVEffectSettings()
    
    // Инициализатор для настройки начального состояния
    init() {
        // Проверяем, установлен ли флаг принудительного использования упрощенного эффекта
        if UserDefaults.standard.bool(forKey: "useSimpleEffectFallback") {
            _useSimpleEffect = State(initialValue: true)
        }
        
        // Инициализируем настройки с более крупными точками
        _tvSettings = StateObject(wrappedValue: {
            let settings = TVEffectSettings()
            settings.noiseSize = 3.0 // Более крупные точки
            settings.applyRetroTVPreset() // Применяем ретро-пресет по умолчанию
            return settings
        }())
    }
    
    func body(content: Content) -> some View {
        Group {
            if useParticleEffect {
                if useSimpleEffect {
                    content.simpleBrokenTVEffect()
                        .preferredColorScheme(.dark)
                } else {
                    content.background(
                        ZStack {
                            TVStaticView(settings: tvSettings)
                                .ignoresSafeArea()
                                .onAppear {
                                    // Загружаем все сохраненные настройки
                                    loadSettings()
                                    
                                    // Оптимизация для 120Hz
                                    tvSettings.refreshRate = 120
                                    
                                    // Если произошла ошибка с Metal, переключаемся на простой эффект
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if Thread.callStackSymbols.contains(where: { $0.contains("fatalError") || $0.contains("EXC_BAD_ACCESS") }) {
                                            useSimpleEffect = true
                                        }
                                    }
                                }
                                .onDisappear {
                                    // Сохраняем все настройки при закрытии
                                    saveSettings()
                                }
                        }
                    )
                    .modifier(MetalErrorHandler(useSimpleEffect: $useSimpleEffect))
                    .preferredColorScheme(.dark)
                }
            } else {
                content.background(Color.black)
                    .preferredColorScheme(.dark)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MetalRenderingError"))) { _ in
            useSimpleEffect = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UseSimpleEffectFallback"))) { _ in
            useSimpleEffect = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UseMetalEffect"))) { _ in
            useSimpleEffect = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetMetalRenderer"))) { _ in
            useSimpleEffect = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TVEffectSettingsChanged"))) { _ in
            // При получении уведомления об изменении настроек перезагружаем их
            loadSettings()
        }
    }
    
    // Добавляем методы для загрузки и сохранения настроек
    private func loadSettings() {
        if let savedNoiseSize = UserDefaults.standard.object(forKey: "tvEffectNoiseSize") as? Double {
            tvSettings.noiseSize = savedNoiseSize
        }
        
        if let particleSpeed = UserDefaults.standard.object(forKey: "tvEffectParticleSpeed") as? Double {
            tvSettings.particleSpeed = particleSpeed
        }
        
        if let refreshRate = UserDefaults.standard.object(forKey: "tvEffectRefreshRate") as? Double {
            tvSettings.refreshRate = refreshRate
        }
        
        if let useScanLines = UserDefaults.standard.object(forKey: "tvEffectUseScanLines") as? Bool {
            tvSettings.useScanLines = useScanLines
        }
        
        if let scanLineDarkness = UserDefaults.standard.object(forKey: "tvEffectScanLineDarkness") as? Double {
            tvSettings.scanLineDarkness = scanLineDarkness
        }
        
        if let isColoredNoise = UserDefaults.standard.object(forKey: "tvEffectIsColoredNoise") as? Bool {
            tvSettings.isColoredNoise = isColoredNoise
        }
        
        if let isHighContrast = UserDefaults.standard.object(forKey: "tvEffectIsHighContrast") as? Bool {
            tvSettings.isHighContrast = isHighContrast
        }
        
        if let useGlitches = UserDefaults.standard.object(forKey: "tvEffectUseGlitches") as? Bool {
            tvSettings.useGlitches = useGlitches
        }
        
        if let glitchIntensity = UserDefaults.standard.object(forKey: "tvEffectGlitchIntensity") as? Double {
            tvSettings.glitchIntensity = glitchIntensity
        }
        
        if let useBlinking = UserDefaults.standard.object(forKey: "tvEffectUseBlinking") as? Bool {
            tvSettings.useBlinking = useBlinking
        }
        
        if let blinkingIntensity = UserDefaults.standard.object(forKey: "tvEffectBlinkingIntensity") as? Double {
            tvSettings.blinkingIntensity = blinkingIntensity
        }
        
        // Если нет сохраненных настроек, применяем ретро-пресет
        if UserDefaults.standard.object(forKey: "tvEffectNoiseSize") == nil {
            tvSettings.applyRetroTVPreset()
            tvSettings.noiseSize = 3.5 // Крупнее по умолчанию
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(tvSettings.noiseSize, forKey: "tvEffectNoiseSize")
        UserDefaults.standard.set(tvSettings.particleSpeed, forKey: "tvEffectParticleSpeed")
        UserDefaults.standard.set(tvSettings.refreshRate, forKey: "tvEffectRefreshRate")
        UserDefaults.standard.set(tvSettings.useScanLines, forKey: "tvEffectUseScanLines")
        UserDefaults.standard.set(tvSettings.scanLineDarkness, forKey: "tvEffectScanLineDarkness")
        UserDefaults.standard.set(tvSettings.isColoredNoise, forKey: "tvEffectIsColoredNoise")
        UserDefaults.standard.set(tvSettings.isHighContrast, forKey: "tvEffectIsHighContrast")
        UserDefaults.standard.set(tvSettings.useGlitches, forKey: "tvEffectUseGlitches")
        UserDefaults.standard.set(tvSettings.glitchIntensity, forKey: "tvEffectGlitchIntensity")
        UserDefaults.standard.set(tvSettings.useBlinking, forKey: "tvEffectUseBlinking")
        UserDefaults.standard.set(tvSettings.blinkingIntensity, forKey: "tvEffectBlinkingIntensity")
    }
}

// Простой эффект сломанного ТВ
// Теперь перенесен в файл BrokenTVEffectModifier.swift для уменьшения дублирования кода
struct SimpleTVEffect: ViewModifier {
    func body(content: Content) -> some View {
        content.simpleBrokenTVEffect()
    }
}

// Специальный модификатор для центрирования баннера
struct CenteredBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
} 