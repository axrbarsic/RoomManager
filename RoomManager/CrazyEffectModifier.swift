import SwiftUI
import Combine

// MARK: - Высокопроизводительный глобальный менеджер эффектов
class HighPerformanceEffectManager: ObservableObject {
    static let shared = HighPerformanceEffectManager()
    
    @Published var isCrazyModeActive: Bool = false
    @Published var intensity: CGFloat = 1.0
    @Published var globalTime: Double = 0
    
    // SMART PERFORMANCE: Адаптивная система эффектов
    @Published var isScrolling: Bool = false
    @Published var scrollPauseActive: Bool = false
    
    // Единственный CADisplayLink для всех эффектов - адаптивная частота
    private var displayLink: CADisplayLink?
    private var currentFPS: Double = 120.0 // ВСЕГДА начинаем с 120fps для максимальной плавности
    private let targetFPS: Double = 120.0
    private let scrollingFPS: Double = 30.0 // Во время скролла снижаем до 30fps
    private var lastTimestamp: CFTimeInterval = 0
    
    // Умный детектор скролла
    private var scrollTimer: Timer?
    private var resumeTimer: Timer?
    private let scrollPauseDelay: TimeInterval = 0.02 // МГНОВЕННАЯ пауза эффектов (было 0.1с)
    private let resumeDelay: TimeInterval = 0.1 // Задержка перед возобновлением
    
         // Кэш преобразований для оптимизации
     private var transformCache: [UUID: CachedTransform] = [:]
     private var cacheUpdateInterval: Double = 1.0 / AppConfiguration.Performance.cacheUpdateFrequency
     private var lastCacheUpdate: CFTimeInterval = 0
     
     // Ограничение количества активных эффектов для производительности
     private var activeEffectsCount: Int = 0
     private let maxActiveEffects = AppConfiguration.Performance.maxConcurrentEffects
    
    init() {
        setupDisplayLink()
        
        // Очищаем ресурсы при переходе в фон
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateGlobalTime))
        
        // ПРИНУДИТЕЛЬНОЕ включение ProMotion 120Hz на поддерживаемых устройствах
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: Float(targetFPS),
            maximum: Float(targetFPS), 
            preferred: Float(targetFPS)
        )
        
        updateDisplayLinkFrameRate()
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.add(to: .main, forMode: .tracking) // Добавляем для tracking mode
        
        print("🚀 ULTRA: CADisplayLink initialized at \(targetFPS)fps MAXIMUM")
    }
    
    // ULTRA PERFORMANCE: Полная остановка CADisplayLink во время скролла
    private func updateDisplayLinkFrameRate() {
        if scrollPauseActive {
            // ПОЛНАЯ ОСТАНОВКА во время скролла для максимальной производительности
            displayLink?.isPaused = true
            currentFPS = 0.0
            print("⚡ ULTRA: CADisplayLink PAUSED for scroll")
            } else {
            // Восстанавливаем работу после скролла - ВСЕГДА 120fps для плавности
            displayLink?.isPaused = false
            currentFPS = targetFPS // ВСЕГДА 120fps для максимальной плавности
            
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(targetFPS),        // Минимум = максимум = 120fps
                maximum: Float(targetFPS),        // Фиксированные 120fps
                preferred: Float(targetFPS)       // Приоритет 120fps
            )
            print("⚡ ULTRA: CADisplayLink RESUMED at \(targetFPS)fps - МАКСИМАЛЬНАЯ СКОРОСТЬ")
        }
    }
    
    // Методы для управления скроллингом
    func startScrollDetection() {
        isScrolling = true
        
        // Сбрасываем предыдущий таймер
        scrollTimer?.invalidate()
        
        // МГНОВЕННАЯ пауза эффектов (минимальная задержка)
        scrollTimer = Timer.scheduledTimer(withTimeInterval: scrollPauseDelay, repeats: false) { _ in
            DispatchQueue.main.async {
                self.scrollPauseActive = true
                self.updateDisplayLinkFrameRate()
                print("⚡ ULTRA: Effects INSTANTLY paused (active: \(self.activeEffectsCount))")
            }
        }
        
        // НЕМЕДЛЕННАЯ остановка обновлений кэша для скорости
        if !scrollPauseActive {
            scrollPauseActive = true
            updateDisplayLinkFrameRate()
        }
    }
    
    func stopScrollDetection() {
        isScrolling = false
        
        // Сбрасываем все таймеры
        scrollTimer?.invalidate()
        scrollTimer = nil
        resumeTimer?.invalidate()
        
        // УМНОЕ ВОССТАНОВЛЕНИЕ: небольшая задержка чтобы скролл полностью остановился
        resumeTimer = Timer.scheduledTimer(withTimeInterval: resumeDelay, repeats: false) { _ in
            DispatchQueue.main.async {
                self.scrollPauseActive = false
                self.updateDisplayLinkFrameRate()
                print("⚡ ULTRA: Effects resumed FULL POWER (active: \(self.activeEffectsCount))")
            }
        }
    }
    
    @objc private func updateGlobalTime() {
        let currentTime = CACurrentMediaTime()
        
        if lastTimestamp > 0 {
            let deltaTime = currentTime - lastTimestamp
            // Ограничиваем deltaTime для стабильности
            let clampedDelta = min(deltaTime, 1.0/60.0)
            globalTime += clampedDelta * Double(intensity)
        }
        
        lastTimestamp = currentTime
        
        // Обновляем кэш преобразований с высокой частотой
        if currentTime - lastCacheUpdate >= cacheUpdateInterval {
            updateTransformCache()
            lastCacheUpdate = currentTime
        }
    }
    
    private func updateTransformCache() {
        // SMART PERFORMANCE: Не обновляем кэш если эффекты приостановлены для скролла
        guard isCrazyModeActive && !scrollPauseActive else { return }
        
        // Предварительно вычисляем преобразования для всех активных ячеек
        for (cellID, _) in transformCache {
            let newTransform = calculateOptimizedTransform(for: cellID)
            transformCache[cellID] = CachedTransform(
                transform: newTransform,
                lastUpdate: CACurrentMediaTime()
            )
        }
    }
    
         func registerCell(_ cellID: UUID) {
         // SMART DUPLICATE CHECK: Проверяем что ячейка ещё не зарегистрирована
         guard transformCache[cellID] == nil else {
             print("🔄 EFFECT: Cell \(cellID.uuidString.prefix(8)) already registered")
             return
         }
         
         // Ограничиваем количество активных эффектов для производительности
         guard activeEffectsCount < maxActiveEffects else {
             print("⚠️ PERFORMANCE: Reached max active effects limit (\(maxActiveEffects))")
             return
         }
         
         transformCache[cellID] = CachedTransform(
             transform: .neutral,
             lastUpdate: CACurrentMediaTime()
         )
         activeEffectsCount += 1
         print("🎯 EFFECT: Registered cell \(cellID.uuidString.prefix(8)), active: \(activeEffectsCount)/\(maxActiveEffects)")
     }
     
     func unregisterCell(_ cellID: UUID) {
         if transformCache.removeValue(forKey: cellID) != nil {
             activeEffectsCount = max(0, activeEffectsCount - 1)
             print("🎯 EFFECT: Unregistered cell \(cellID.uuidString.prefix(8)), active: \(activeEffectsCount)/\(maxActiveEffects)")
         }
     }
    
    func getTransform(for cellID: UUID) -> RandomTransform {
        guard isCrazyModeActive else { return .neutral }
        
        if let cached = transformCache[cellID] {
            return cached.transform
        } else {
            // Регистрируем новую ячейку и возвращаем нейтральное преобразование
            registerCell(cellID)
            return .neutral
        }
    }
    
    private func calculateOptimizedTransform(for cellID: UUID) -> RandomTransform {
        // SMART PERFORMANCE: Возвращаем нейтральный трансформ если эффекты приостановлены для скролла
        guard !scrollPauseActive else {
            return .neutral
        }
        
        // Используем хэш UUID для уникального offset каждой ячейки
        let cellHash = Double(cellID.hashValue % 1000) / 1000.0
        let time = globalTime + cellHash * 10.0
        
        // Оптимизированные тригонометрические вычисления
        let wave1 = sin(time * 2.0)
        let wave2 = cos(time * 1.7 + cellHash * 6.28)
        let combinedWave = wave1 * wave2 * 0.5
        
        // Минимальные преобразования для максимальной производительности
        let rotation = combinedWave * 1.5 * Double(intensity) // Уменьшил с 2.0 до 1.5
        let scale = 1.0 + (combinedWave * 0.015 * intensity) // Уменьшил с 0.02 до 0.015
        
        return RandomTransform(
            rotation: .degrees(rotation),
            scale: scale,
            wave: CGFloat(combinedWave * 0.3) // Уменьшил волновой эффект
        )
    }
    
    @objc private func handleDidEnterBackground() {
        displayLink?.isPaused = true
    }
    
    @objc private func handleWillEnterForeground() {
        displayLink?.isPaused = false
}

    // Публичный метод для принудительного обновления частоты кадров
    func forceUpdateFrameRate() {
        // Принудительно устанавливаем 120fps без зависимости от scrollPauseActive
        currentFPS = targetFPS
        displayLink?.isPaused = false
        
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: Float(targetFPS),
            maximum: Float(targetFPS),
            preferred: Float(targetFPS)
        )
        print("🚀 ULTRA: FORCED frame rate to \(currentFPS)fps MAXIMUM")
    }
    
    // EMERGENCY: Сброс всех эффектов для отладки
    func resetAllEffects() {
        transformCache.removeAll()
        activeEffectsCount = 0
        scrollPauseActive = false
        scrollTimer?.invalidate()
        scrollTimer = nil
        resumeTimer?.invalidate()
        resumeTimer = nil
        updateDisplayLinkFrameRate()
        print("🔄 EMERGENCY: All effects reset, count: \(activeEffectsCount)")
    }
    
    deinit {
        displayLink?.invalidate()
        scrollTimer?.invalidate()
        resumeTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// Кэшированное преобразование
struct CachedTransform {
    let transform: RandomTransform
    let lastUpdate: CFTimeInterval
}

// MARK: - Высокопроизводительный модификатор эффектов
struct OptimizedCrazyEffectModifier: ViewModifier {
    let cellID: UUID
    @ObservedObject private var effectManager = HighPerformanceEffectManager.shared
    
    func body(content: Content) -> some View {
        Group {
            if effectManager.isCrazyModeActive {
                let transform = effectManager.getTransform(for: cellID)
                
                content
                    .scaleEffect(transform.scale)
                    .rotationEffect(transform.rotation)
                    // Убираем WaveEffect - он слишком тяжелый для GPU
                    // .modifier(OptimizedWaveEffect(wave: transform.wave))
                    .animation(
                        // ULTRA: Убираем ВСЕ анимации во время скролла для 120fps
                        effectManager.scrollPauseActive ? .none : .linear(duration: AppConfiguration.Performance.effectTransitionDuration), 
                        value: transform
                    )
                    // Убираем drawingGroup - может конфликтовать со скроллингом
            } else {
                content
                // Нет модификаторов для статичного состояния для максимальной производительности
            }
        }
        .onAppear {
            effectManager.registerCell(cellID)
        }
        .onDisappear {
            effectManager.unregisterCell(cellID)
        }
    }
}

// MARK: - Легкий волновой эффект (опционально)
struct OptimizedWaveEffect: GeometryEffect {
    var wave: CGFloat
    
    var animatableData: CGFloat {
        get { wave }
        set { wave = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        // Минимальное искривление только если wave > пороговое значение
        guard abs(wave) > 0.1 else { return ProjectionTransform(.identity) }
        
        // Упрощенное преобразование без 3D
        let angle = wave * .pi / 60 // Еще меньший угол для производительности
        let transform = CGAffineTransform(rotationAngle: angle)
        
        return ProjectionTransform(transform)
    }
}

// MARK: - Совместимость с существующим кодом
struct CrazyEffectModifier: ViewModifier {
    let cellID: UUID
    
    func body(content: Content) -> some View {
        content.modifier(OptimizedCrazyEffectModifier(cellID: cellID))
    }
}

// Сохраняем старый интерфейс для совместимости
extension View {
    func crazyEffect(cellID: UUID) -> some View {
        self.modifier(OptimizedCrazyEffectModifier(cellID: cellID))
    }
} 