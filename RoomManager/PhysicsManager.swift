import SwiftUI
import Combine

class PhysicsManager: ObservableObject {
    static let shared = PhysicsManager()
    
    // Флаг, указывающий, что хаос включён (ячейки должны двигаться)
    @Published var isChaosActive: Bool = false {
        didSet {
            // Синхронизируем с новой высокопроизводительной системой
            HighPerformanceEffectManager.shared.isCrazyModeActive = isChaosActive
        }
    }
    
    // Переменная для совместимости с существующим кодом
    @Published var chaosTick: Double = 0
    
    // Имя уведомления для оповещения об изменениях
    static let chaosStartedNotification = Notification.Name("chaosStartedNotification")
    
    // Убираем Timer - теперь используем CADisplayLink из HighPerformanceEffectManager
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Подписываемся на изменения глобального времени для совместимости
        HighPerformanceEffectManager.shared.$globalTime
            .assign(to: \.chaosTick, on: self)
            .store(in: &cancellables)
        
        // При переходе в фон останавливаем хаотичное движение
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }
    
    @objc private func handleDidEnterBackground() {
        stopChaos()
    }
    
    func startChaos() {
        guard !isChaosActive else { return }
        
        // Активируем высокопроизводительную систему эффектов
        isChaosActive = true
        HighPerformanceEffectManager.shared.isCrazyModeActive = true
        HighPerformanceEffectManager.shared.intensity = 1.0
        
        // Посылаем уведомление о том, что хаос начался
        NotificationCenter.default.post(name: PhysicsManager.chaosStartedNotification, object: nil)
        
        print("🎯 PHYSICS: Chaos started with high-performance system")
    }
    
    func stopChaos() {
        guard isChaosActive else { return }
        
        // Плавно отключаем эффекты
        HighPerformanceEffectManager.shared.intensity = 0.0
        
        // Отключаем хаос с задержкой для плавности
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.isChaosActive = false
                HighPerformanceEffectManager.shared.isCrazyModeActive = false
            }
        }
        
        print("🎯 PHYSICS: Chaos stopped")
    }
    
    // Метод для быстрой остановки без анимации (для экстренных случаев)
    func stopChaosImmediately() {
        isChaosActive = false
        HighPerformanceEffectManager.shared.isCrazyModeActive = false
        HighPerformanceEffectManager.shared.intensity = 0.0
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cancellables.removeAll()
    }
}

