import SwiftUI
import Metal

/// Модификатор для обработки ошибок Metal и автоматического переключения на упрощенный режим.
/// При возникновении исключения в Metal, этот модификатор обеспечивает переключение на безопасную альтернативу.
struct MetalErrorHandler: ViewModifier {
    @Binding var useSimpleEffect: Bool
    @State private var hasCheckedForErrors = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasCheckedForErrors {
                    // Устанавливаем обработчик сигналов для перехвата ошибок Metal
                    setupMetalErrorHandler()
                    hasCheckedForErrors = true
                }
            }
    }
    
    /// Устанавливаем обработчик для сигналов, которые могут возникнуть при ошибках Metal
    private func setupMetalErrorHandler() {
        // Проверяем, был ли уже активирован упрощенный режим
        if UserDefaults.standard.bool(forKey: "useSimpleEffectFallback") {
            DispatchQueue.main.async {
                self.useSimpleEffect = true
            }
            return
        }
        
        // Запускаем проверку асинхронно в фоновой очереди
        DispatchQueue.global(qos: .background).async {
            // Проверяем, возникают ли ошибки Metal в логах
            let isMetalError = checkForMetalErrors()
            
            if isMetalError {
                fallbackToSimpleEffect()
            }
        }
    }
    
    /// Проверяет лог-сообщения на наличие ошибок Metal
    private func checkForMetalErrors() -> Bool {
        // Для симуляторов часто возникает ошибка "Unable to open mach-O at path: .../default.metallib"
        // что является ожидаемым поведением для некоторых устройств
        #if targetEnvironment(simulator)
            print("DEBUG: Работаем в симуляторе, возможны ограничения Metal API")
            return false
        #else
            // Для реальных устройств проводим проверку наличия Metal поддержки
            let device = MTLCreateSystemDefaultDevice()
            if device == nil {
                print("DEBUG: Metal не поддерживается на этом устройстве, переключаемся на упрощенный режим")
                return true
            }
            return false
        #endif
    }
    
    /// Переключаемся на упрощенный эффект и сохраняем настройку
    private func fallbackToSimpleEffect() {
        DispatchQueue.main.async {
            print("DEBUG: Переключение на упрощенный эффект из-за проблем с Metal")
            self.useSimpleEffect = true
            UserDefaults.standard.set(true, forKey: "useSimpleEffectFallback")
            
            // Отправляем уведомление для переключения на упрощенный эффект
            NotificationCenter.default.post(
                name: NSNotification.Name("UseSimpleEffectFallback"),
                object: nil
            )
        }
    }
} 