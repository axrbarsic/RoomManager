import SwiftUI
import Combine

/// Структура, описывающая случайное преобразование
struct RandomTransform: Equatable {
    var rotation: Angle
    var scale: CGFloat
    var wave: CGFloat
    
    static let neutral = RandomTransform(rotation: .zero, scale: 1.0, wave: 0)
}

/// Менеджер случайных эффектов (теперь является обёрткой для HighPerformanceEffectManager)
class RandomEffectManager: ObservableObject {
    static let shared = RandomEffectManager()
    
    /// Флаг: активен ли безумный режим (проксирует к новой системе)
    @Published var isCrazyModeActive: Bool = false {
        didSet {
            // Синхронизируем с высокопроизводительной системой
            HighPerformanceEffectManager.shared.isCrazyModeActive = isCrazyModeActive
        }
    }
    
    /// Интенсивность эффекта (проксирует к новой системе)
    @Published var intensity: CGFloat = 1.0 {
        didSet {
            // Синхронизируем с высокопроизводительной системой
            HighPerformanceEffectManager.shared.intensity = intensity
        }
    }
    
    /// Текущее случайное преобразование (для совместимости)
    @Published var currentTransform: RandomTransform = .neutral
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Подписываемся на изменения в высокопроизводительной системе
        HighPerformanceEffectManager.shared.$isCrazyModeActive
            .assign(to: \.isCrazyModeActive, on: self)
            .store(in: &cancellables)
        
        HighPerformanceEffectManager.shared.$intensity
            .assign(to: \.intensity, on: self)
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
} 